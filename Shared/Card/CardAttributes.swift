import Foundation
import SwiftASN1

/// Common object attributes precede the certificate or key-specific fields.
/// User consent and access-control metadata do not affect the supported authentication profile.
struct CommonObjectAttributes {
    let label: String?
    let authID: Data?
}

extension CommonObjectAttributes: CardRecord {
    init(berEncoded node: ASN1Node) throws {
        self = try BER.sequence(node, identifier: .sequence) { fields in
            let label: ASN1UTF8String? = try BER.optionalImplicitlyTagged(&fields)
            let _: ASN1BitString? = try BER.optionalImplicitlyTagged(&fields)
            let authID: ASN1OctetString? = try BER.optionalImplicitlyTagged(&fields)
            fields.discardRemaining()
            return Self(label: label.flatMap { String(data: Data($0.bytes), encoding: .utf8) },
                        authID: authID.map { Data($0.bytes) })
        }
    }
}

/// Dates, native-key and access flags are outside the authentication-key selection criteria.
struct CommonKeyAttributes {
    let id: Data
    let usage: KeyUsage
    let reference: UInt32?
}

extension CommonKeyAttributes: CardRecord {
    init(berEncoded node: ASN1Node) throws {
        self = try BER.sequence(node, identifier: .sequence) { fields in
            let id = try ASN1OctetString(berEncoded: &fields)
            let usage = try ASN1BitString(berEncoded: &fields).options(as: KeyUsage.self)
            _ = try BER.optionalImplicitlyTagged(&fields, tagNumber: 1, tagClass: .universal) {
                try Bool(berEncoded: $0)
            }
            let _: ASN1BitString? = try BER.optionalImplicitlyTagged(&fields)
            let reference = try BER.optionalImplicitlyTagged(&fields, tagNumber: 2, tagClass: .universal) {
                try UInt32(berEncoded: $0)
            }
            fields.discardRemaining()
            return Self(id: Data(id.bytes), usage: usage, reference: reference)
        }
    }
}
