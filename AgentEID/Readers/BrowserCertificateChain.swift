import Foundation
import Security

enum BrowserCertificateChain {
    /// Security's issuer lookup does not search token-published CA certificates.
    /// Register only the authentication chain's intermediates, without trust overrides.
    static func register(identity: AuthenticationIdentity, publicData: PublicCardData) throws {
        guard let leaf = SecCertificateCreateWithData(nil, identity.certificate.der as CFData) else {
            throw CardDataError.invalidAuthenticationCertificate
        }
        let certificates = [leaf] + publicData.certificates.compactMap {
            SecCertificateCreateWithData(nil, $0.der as CFData)
        }
        var trust: SecTrust?
        guard SecTrustCreateWithCertificates(certificates as CFArray, SecPolicyCreateSSL(false, nil), &trust) == errSecSuccess,
              let trust else { throw CardDataError.cannotBuildCertificateChain }
        SecTrustSetNetworkFetchAllowed(trust, false)
        _ = SecTrustEvaluateWithError(trust, nil)
        guard let chain = SecTrustCopyCertificateChain(trust) as? [SecCertificate], chain.count > 1 else {
            throw CardDataError.missingIssuerCertificate
        }
        for issuer in chain.dropFirst() {
            guard SecCertificateCopyNormalizedSubjectSequence(issuer) != SecCertificateCopyNormalizedIssuerSequence(issuer) else { continue }
            let query: [CFString: Any] = [kSecClass: kSecClassCertificate, kSecValueRef: issuer]
            let status = SecItemAdd(query as CFDictionary, nil)
            guard status == errSecSuccess || status == errSecDuplicateItem else {
                throw CardDataError.cannotRegisterIssuerCertificate(status: status)
            }
        }
    }
}
