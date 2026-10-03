import Foundation
import SwiftASN1

extension Data {
    var hex: String { map { String(format: "%02X", $0) }.joined() }
}

/// A file path of two-byte identifiers, optionally restricted to a byte range.
/// A leading master-file identifier makes a multi-file path absolute; omitted length means read to EOF.
struct CardPath: Equatable, Sendable {
    let bytes: Data
    let offset: Int
    let length: Int?

    enum File: UInt16 {
        case masterFile = 0x3F00
        case cardInfo = 0x5032
        case objectDirectory = 0x5031

        var bytes: Data { Data([UInt8(rawValue >> 8), UInt8(truncatingIfNeeded: rawValue)]) }
    }

    init(file: File) throws {
        try self.init(bytes: file.bytes)
    }

    init(bytes: Data, offset: Int = 0, length: Int? = nil) throws {
        guard bytes.count >= 2, bytes.count <= 16, bytes.count.isMultiple(of: 2),
              offset >= 0, offset < 32_768,
              length.map({ $0 > 0 && $0 <= 32_768 - offset }) ?? true else {
            throw CardDataError.invalidFilePathOrRange
        }
        self.bytes = bytes
        self.offset = offset
        self.length = length
    }

}

extension CardPath: CardRecord {
    init(berEncoded node: ASN1Node) throws {
        self = try BER.sequence(node, identifier: .sequence) { fields in
            let bytes = try ASN1OctetString(berEncoded: &fields)
            let offset = try BER.decodeDefault(&fields, identifier: .integer, defaultValue: UInt32(0)) {
                try UInt32(berEncoded: $0)
            }
            let length = try BER.optionalImplicitlyTagged(&fields, tagNumber: 0, tagClass: .contextSpecific) {
                try UInt32(berEncoded: $0, withIdentifier: $0.identifier)
            }
            return try Self(bytes: Data(bytes.bytes), offset: Int(offset), length: length.map(Int.init))
        }
    }
}

/// An object-directory entry points to a directory of one PKCS #15 object kind, not to an object itself.
struct CardDirectory: Equatable, Sendable {
    let kind: Kind
    let path: CardPath

    enum Kind: UInt {
        case privateKeys = 0
        case publicKeys = 1
        case trustedPublicKeys = 2
        case secretKeys = 3
        case certificates = 4
        case trustedCertificates = 5
        case usefulCertificates = 6
        case dataObjects = 7
        case authenticationObjects = 8
    }

    static func decode(_ data: Data) throws -> [CardDirectory] {
        try parseCardRecords(data, as: Self.self)
    }
}

extension CardDirectory: CardRecord {
    init(berEncoded node: ASN1Node) throws {
        guard node.identifier.tagClass == .contextSpecific,
              let kind = Kind(rawValue: node.identifier.tagNumber) else {
            throw CardDataError.unsupportedDirectoryEntry
        }
        let path = try BER.explicitlyTagged(node, tagNumber: kind.rawValue, tagClass: .contextSpecific) {
            try CardPath(berEncoded: $0)
        }
        self.init(kind: kind, path: path)
    }
}

/// Certificate-directory metadata; the certificate bytes are read separately from `path`.
/// Its object ID associates the certificate with the corresponding private-key entry.
struct CertificateReference: Equatable, Sendable {
    let id: Data
    let label: String
    let path: CardPath

    static func decode(_ data: Data) throws -> [CertificateReference] {
        try parseCardRecords(data, as: Self.self)
    }
}

extension CertificateReference: CardRecord {
    init(berEncoded node: ASN1Node) throws {
        self = try BER.sequence(node, identifier: .sequence) { fields in
            let object = try CommonObjectAttributes(berEncoded: &fields)
            let id = try BER.sequence(fields.nextRequired(), identifier: .sequence) { attributes in
                let id = try ASN1OctetString(berEncoded: &attributes)
                attributes.discardRemaining()
                return Data(id.bytes)
            }
            _ = BER.optionalImplicitlyTagged(&fields, tagNumber: 0, tagClass: .contextSpecific) { $0 }
            let path = try BER.explicitlyTagged(fields.nextRequired(), tagNumber: 1, tagClass: .contextSpecific) { type in
                try BER.sequence(type, identifier: .sequence) { attributes in
                    let path = try CardPath(berEncoded: &attributes)
                    attributes.discardRemaining()
                    return path
                }
            }
            fields.discardRemaining()
            return Self(id: id, label: object.label ?? String(localized: .cardCertificateDefaultLabel), path: path)
        }
    }
}

/// CIAInfo metadata used for token identity and algorithm negotiation.
/// The serial is opaque bytes; mechanisms include only algorithms whose usage permits signatures.
struct CardInfo: Equatable, Sendable {
    let serial: Data
    let label: String
    let mechanisms: Set<CryptographicMechanism>

    static func decode(_ data: Data) throws -> CardInfo {
        let records = try parseCardRecords(data, as: Self.self)
        guard records.count == 1, let info = records.first else {
            throw CardDataError.missingSerialNumber
        }
        return info
    }
}

extension CardInfo: CardRecord {
    init(berEncoded root: ASN1Node) throws {
        self = try BER.sequence(root, identifier: .sequence) { fields in
            _ = try UInt32(berEncoded: &fields)
            let serial = try ASN1OctetString(berEncoded: &fields)
            guard !serial.bytes.isEmpty else {
                throw CardDataError.missingSerialNumber
            }
            var label = String(localized: .cardDefaultLabel)
            var mechanisms: Set<CryptographicMechanism> = []
            while let field = fields.next() {
                switch field.identifier {
                case ASN1Identifier(tagWithNumber: 0, tagClass: .contextSpecific):
                    let value = try ASN1UTF8String(berEncoded: field, withIdentifier: field.identifier)
                    label = String(data: Data(value.bytes), encoding: .utf8) ?? label
                case ASN1Identifier(tagWithNumber: 2, tagClass: .contextSpecific):
                    mechanisms = try BER.sequence(field, identifier: field.identifier) { algorithms in
                        var mechanisms: Set<CryptographicMechanism> = []
                        while let algorithm = algorithms.next() {
                            if let mechanism = try Self.signatureMechanism(algorithm) { mechanisms.insert(mechanism) }
                        }
                        return mechanisms
                    }
                default: break
                }
            }
            return Self(serial: Data(serial.bytes), label: label, mechanisms: mechanisms)
        }
    }

    /// Ignore incomplete or non-signing entries; malformed signing values still fail discovery.
    private static func signatureMechanism(_ node: ASN1Node) throws -> CryptographicMechanism? {
        guard node.identifier == .sequence, case .constructed = node.content else { return nil }
        return try BER.sequence(node, identifier: .sequence) { fields in
            guard fields.next() != nil, let mechanism = fields.next(), mechanism.identifier == .integer,
                  fields.next() != nil, let usage = fields.next(), usage.identifier == .bitString else {
                fields.discardRemaining()
                return nil
            }
            fields.discardRemaining()
            guard try ASN1BitString(berEncoded: usage).options(as: AlgorithmUsage.self).contains(.signature) else {
                return nil
            }
            return try CryptographicMechanism(rawValue: Int(UInt32(berEncoded: mechanism)))
        }
    }
}
