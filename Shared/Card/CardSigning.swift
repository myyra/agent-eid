import CryptoTokenKit
import Foundation
import Security
import SwiftASN1

/// PKCS #11 mechanism identifiers are open-ended; retain mechanisms we do not implement.
struct CryptographicMechanism: RawRepresentable, Hashable, Sendable {
    let rawValue: Int
    static let ecdsaSHA256 = Self(rawValue: 4164)
    static let ecdsaSHA384 = Self(rawValue: 4165)
    static let ecdsaSHA512 = Self(rawValue: 4166)
}

/// Maps a digest choice between Security algorithms, PKCS #11 mechanisms and FINeID MSE references.
/// The caller supplies the digest; these cases do not hash message data.
enum ECSignatureAlgorithm: CaseIterable, Sendable {
    case sha256, sha384, sha512

    var digestLength: Int {
        switch self { case .sha256: 32; case .sha384: 48; case .sha512: 64 }
    }
    var mechanism: CryptographicMechanism {
        switch self { case .sha256: .ecdsaSHA256; case .sha384: .ecdsaSHA384; case .sha512: .ecdsaSHA512 }
    }
    var reference: UInt8 {
        switch self { case .sha256: 0x44; case .sha384: 0x54; case .sha512: 0x64 }
    }
    var secKeyAlgorithm: SecKeyAlgorithm {
        switch self {
        case .sha256: .ecdsaSignatureDigestX962SHA256
        case .sha384: .ecdsaSignatureDigestX962SHA384
        case .sha512: .ecdsaSignatureDigestX962SHA512
        }
    }

    /// Resolve explicit or generic ECDSA requests only when the supplied digest length matches.
    static func resolve(_ algorithm: TKTokenKeyAlgorithm, digestLength: Int) -> Self? {
        let specific = allCases.first { algorithm.isAlgorithm($0.secKeyAlgorithm) }
            ?? allCases.first {
                algorithm.isAlgorithm(.ecdsaSignatureDigestX962) && algorithm.supportsAlgorithm($0.secKeyAlgorithm)
            }
        if let specific { return specific.digestLength == digestLength ? specific : nil }
        guard algorithm.isAlgorithm(.ecdsaSignatureDigestX962) else { return nil }
        return allCases.first { $0.digestLength == digestLength }
    }

    /// Advertise generic ECDSA only when every digest variant can be serviced by this card.
    static func supports(_ algorithm: TKTokenKeyAlgorithm, mechanisms: Set<CryptographicMechanism>) -> Bool {
        if algorithm.isAlgorithm(.ecdsaSignatureDigestX962) {
            return allCases.allSatisfy { mechanisms.contains($0.mechanism) }
        }
        return allCases.contains { mechanisms.contains($0.mechanism) && algorithm.isAlgorithm($0.secKeyAlgorithm) }
    }
}

enum ECDSASignature {
    /// FINeID returns fixed-width r || s; Security expects DER INTEGERs in an X9.62 SEQUENCE.
    static func der(_ raw: Data, coordinateLength: Int) throws -> Data {
        guard coordinateLength > 0, coordinateLength <= 66, raw.count == coordinateLength * 2 else {
            throw CardDataError.invalidSignatureLength
        }
        var serializer = DER.Serializer()
        try serializer.appendConstructedNode(identifier: .sequence) {
            try $0.serialize(Component(derIntegerBytes: ArraySlice(raw.prefix(coordinateLength))))
            try $0.serialize(Component(derIntegerBytes: ArraySlice(raw.suffix(coordinateLength))))
        }
        return Data(serializer.serializedBytes)
    }

    /// Unsigned, arbitrary-width magnitudes let SwiftASN1 supply DER sign padding.
    private struct Component: ASN1IntegerRepresentable {
        static let isSigned = false
        let bytes: ArraySlice<UInt8>

        init(derIntegerBytes bytes: ArraySlice<UInt8>) throws {
            self.bytes = bytes.drop(while: { $0 == 0 })
            guard !self.bytes.isEmpty else {
                throw CardDataError.zeroSignatureComponent
            }
        }

        init(berIntegerBytes bytes: ArraySlice<UInt8>) throws {
            try self.init(derIntegerBytes: bytes)
        }

        func withBigEndianIntegerBytes<Result>(_ body: (ArraySlice<UInt8>) throws -> Result) rethrows -> Result {
            try body(bytes)
        }
    }
}

extension CardChannel {
    /// Empty VERIFY queries authentication state without consuming a PIN retry.
    /// An already-verified card status does not replace the token session's per-signature grant.
    func pinStatus(_ pin: PINReference) throws -> CardStatus {
        try send(.pinStatus(reference: pin.reference)).status
    }

    /// Validate and pad PIN input, then send one VERIFY; a card rejection is never retried here.
    func verify(_ pin: String, reference: PINReference) throws {
        var encoded = try reference.encode(pin)
        defer { encoded.resetBytes(in: 0..<encoded.count) }
        let response = try send(.verifyPIN(reference: reference.reference, encodedPIN: encoded))
        try requireSuccess(response)
    }

    /// Requires prior PIN verification in the active card session.
    /// Sends the digest unchanged through MSE, PSO HASH and PSO SIGN, returning a DER signature.
    func sign(_ digest: Data, identity: AuthenticationIdentity, algorithm: ECSignatureAlgorithm) throws -> Data {
        guard digest.count == algorithm.digestLength else {
            throw CardDataError.invalidDigestLength
        }
        try requireSuccess(send(.prepareSignature(algorithm: algorithm, keyReference: identity.key.reference)))
        try requireSuccess(send(.submitDigest(digest)))
        let coordinateLength = AuthenticationProfile.signatureCoordinateLength
        let result = try send(.computeSignature(responseLength: coordinateLength * 2))
        try requireSuccess(result)
        return try ECDSASignature.der(result.response, coordinateLength: coordinateLength)
    }

    func requireSuccess(_ response: CardResponse) throws {
        guard response.status == .success else { throw CardDataError.status(response.status) }
    }
}
