import Foundation
import SwiftASN1

/// PKCS #15 key capabilities; bit positions differ from the algorithm-usage flags.
struct KeyUsage: OptionSet, Sendable {
    let rawValue: UInt
    static let sign = Self(rawValue: 1 << 2)
}

/// Operations advertised by an algorithm entry in CIAInfo.
struct AlgorithmUsage: OptionSet, Sendable {
    let rawValue: UInt
    static let signature = Self(rawValue: 1 << 1)
}

/// PIN lifecycle flags from the authentication-object directory.
struct PINFlags: OptionSet, Sendable {
    let rawValue: UInt
    static let initialized = Self(rawValue: 1 << 4)
}
enum PINEncoding: Int { case numericASCII = 1 }

/// Public metadata describing a card-resident key; no private-key material is read.
struct PrivateKeyReference: Equatable, Sendable {
    let id: Data
    /// Links to a PIN object ID; it is distinct from the command-level key reference.
    let authID: Data
    let reference: UInt8
    let canSign: Bool
    let curve: ASN1ObjectIdentifier?
    /// An empty key path denotes a key in the application root, unlike a readable file path.
    let path: Data

    static func decode(_ data: Data) throws -> [PrivateKeyReference] {
        try parseCardRecords(data, as: Self.self)
    }
}

extension PrivateKeyReference: CardRecord {
    init(berEncoded record: ASN1Node) throws {
        let ecKey = ASN1Identifier(tagWithNumber: 0, tagClass: .contextSpecific)
        guard record.identifier == ecKey || record.identifier == .sequence else {
            throw CardDataError.invalidPrivateKeyMetadata
        }
        self = try BER.sequence(record, identifier: record.identifier) { fields in
            let object = try CommonObjectAttributes(berEncoded: &fields)
            let key = try CommonKeyAttributes(berEncoded: &fields)
            guard let authID = object.authID, let reference = key.reference, (1...255).contains(reference) else {
                throw CardDataError.invalidPrivateKeyMetadata
            }
            _ = BER.optionalImplicitlyTagged(&fields, tagNumber: 0, tagClass: .contextSpecific) { $0 }
            let (path, curve) = try BER.explicitlyTagged(fields.nextRequired(), tagNumber: 1, tagClass: .contextSpecific) { type in
                let path = try BER.sequence(type, identifier: .sequence) { attributes in
                    let path = try BER.sequence(attributes.nextRequired(), identifier: .sequence) { pathFields in
                        let path = try ASN1OctetString(berEncoded: &pathFields)
                        pathFields.discardRemaining()
                        return Data(path.bytes)
                    }
                    attributes.discardRemaining()
                    return path
                }
                let curve = record.identifier == ecKey
                    ? try type.first(identifier: .objectIdentifier).map { try ASN1ObjectIdentifier(berEncoded: $0) } : nil
                return (path, curve)
            }
            fields.discardRemaining()
            return Self(id: key.id, authID: authID, reference: UInt8(reference),
                        canSign: key.usage.contains(.sign), curve: curve, path: path)
        }
    }
}

/// PIN-object metadata supplies the VERIFY reference, encoding and fixed-width padding rules.
/// The object ID links keys to this PIN; it is not the reference byte sent in VERIFY.
struct PINReference: Equatable, Sendable {
    let id: Data
    let reference: UInt8
    let minimumLength: Int
    let maximumLength: Int
    let storedLength: Int
    let padding: UInt8
    let initialized: Bool
    let numericASCII: Bool

    static func decode(_ data: Data) throws -> [PINReference] {
        try parseCardRecords(data, as: Self.self)
    }

    /// Validates numeric input and pads it to the card-declared stored length.
    /// Invalid input fails locally, before any VERIFY command can consume a retry.
    func encode(_ pin: String) throws -> Data {
        let bytes = pin.utf8
        guard numericASCII, (minimumLength...maximumLength).contains(bytes.count),
              bytes.allSatisfy({ (0x30...0x39).contains($0) }) else {
            throw CardDataError.invalidPIN(minimumLength: minimumLength, maximumLength: maximumLength)
        }
        return Data(bytes) + Data(repeating: padding, count: storedLength - bytes.count)
    }
}

extension PINReference: CardRecord {
    init(berEncoded record: ASN1Node) throws {
        self = try BER.sequence(record, identifier: .sequence) { fields in
            _ = try CommonObjectAttributes(berEncoded: &fields)
            let id = try BER.sequence(fields.nextRequired(), identifier: .sequence) { attributes in
                let id = try ASN1OctetString(berEncoded: &attributes)
                attributes.discardRemaining()
                return Data(id.bytes)
            }
            let pin = try BER.explicitlyTagged(fields.nextRequired(), tagNumber: 1, tagClass: .contextSpecific) { type in
                try BER.sequence(type, identifier: .sequence) { attributes in
                    let flags = try ASN1BitString(berEncoded: &attributes).options(as: PINFlags.self)
                    let encoding = try UInt32(berEncoded: attributes.nextRequired(), withIdentifier: .enumerated)
                    let minimum = try UInt32(berEncoded: &attributes)
                    let stored = try UInt32(berEncoded: &attributes)
                    let maximum = try BER.decodeDefault(&attributes, identifier: .integer, defaultValue: stored) {
                        try UInt32(berEncoded: $0)
                    }
                    let reference = try BER.optionalImplicitlyTagged(&attributes, tagNumber: 0, tagClass: .contextSpecific) {
                        try UInt32(berEncoded: $0, withIdentifier: $0.identifier)
                    }
                    let padding = try ASN1OctetString(berEncoded: &attributes)
                    guard let reference, (1...255).contains(reference), padding.bytes.count == 1,
                          let paddingByte = padding.bytes.first,
                          minimum > 0, minimum <= maximum, maximum <= stored, stored <= 16 else {
                        throw CardDataError.invalidPINMetadata
                    }
                    attributes.discardRemaining()
                    return Self(id: id, reference: UInt8(reference), minimumLength: Int(minimum),
                                maximumLength: Int(maximum), storedLength: Int(stored), padding: paddingByte,
                                initialized: flags.contains(.initialized), numericASCII: encoding == PINEncoding.numericASCII.rawValue)
                }
            }
            fields.discardRemaining()
            return pin
        }
    }
}

/// A matched key, PIN and certificate exposed as one CryptoTokenKit signing identity.
struct AuthenticationIdentity: Sendable {
    let key: PrivateKeyReference
    let pin: PINReference
    let certificate: PublicCertificate

    var objectID: String { "auth-\(key.id.hex)" }
    var constraint: String { "pin-\(pin.id.hex)" }
}

/// Initial signing profile: FINeID EC authentication with PIN1 and a root-level key.
/// PIN2 and RSA document-signing keys are deliberately excluded.
enum AuthenticationProfile {
    static let pin1Reference: UInt8 = 0x11
    static let signatureCoordinateLength = 48

    /// Match directory object IDs and reject missing, unsupported or ambiguous identities.
    static func identity(
        publicData: PublicCardData, keys: [PrivateKeyReference], pins: [PINReference]
    ) throws -> AuthenticationIdentity {
        let matches = keys.compactMap { key -> AuthenticationIdentity? in
            guard key.canSign, key.curve == ASN1ObjectIdentifier.NamedCurves.secp384r1, key.path.isEmpty,
                  let pin = pins.first(where: { $0.id == key.authID }),
                  pin.reference == pin1Reference, pin.numericASCII, pin.storedLength == 12, pin.padding == 0,
                  let certificate = publicData.certificates.first(where: { $0.reference.id == key.id }) else {
                return nil
            }
            return AuthenticationIdentity(key: key, pin: pin, certificate: certificate)
        }
        guard matches.count == 1, let identity = matches.first else {
            throw CardDataError.unsupportedAuthenticationKeyProfile
        }
        guard identity.pin.initialized else {
            throw CardDataError.pinNotActivated
        }
        return identity
    }
}
