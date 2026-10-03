import Foundation
import Security

/// Public identity details from the authentication certificate, read without verifying a PIN.
struct PreparedCard: Sendable {
    let authenticationCertificate: Data
    let holderName: String?

    /// FINeID common names may include an identifier; prefer the separate personal-name attributes.
    init(authenticationCertificate: Data) throws {
        guard let certificate = SecCertificateCreateWithData(nil, authenticationCertificate as CFData) else {
            throw CardDataError.invalidAuthenticationCertificate
        }
        self.authenticationCertificate = authenticationCertificate
        let values = SecCertificateCopyValues(certificate, [kSecOIDX509V1SubjectName] as CFArray, nil) as? [String: Any]
        let subject = values?[kSecOIDX509V1SubjectName as String] as? [String: Any]
        let attributes = subject?[kSecPropertyKeyValue as String] as? [[String: Any]] ?? []
        func nameAttribute(_ oid: CFString) -> String? {
            let field = attributes.first { $0[kSecPropertyKeyLabel as String] as? String == oid as String }
            let value = (field?[kSecPropertyKeyValue as String] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return value.flatMap { $0.isEmpty ? nil : $0 }
        }
        if let givenName = nameAttribute(kSecOIDGivenName), let surname = nameAttribute(kSecOIDSurname) {
            var name = PersonNameComponents()
            name.givenName = givenName
            name.familyName = surname
            holderName = name.formatted(.name(style: .long))
        } else {
            var commonName: CFString?
            let status = SecCertificateCopyCommonName(certificate, &commonName)
            let value = status == errSecSuccess ? (commonName as String?)?.trimmingCharacters(in: .whitespacesAndNewlines) : nil
            holderName = value.flatMap { $0.isEmpty ? nil : $0 }
        }
    }
}
