import CryptoTokenKit
import Security
import OSLog

/// Publishes card certificates and the supported authentication key to macOS.
/// Discovery reads metadata only; authentication is deferred to individual token sessions.
final class Token: TKSmartCardToken, TKTokenDelegate {
    let identity: AuthenticationIdentity
    let mechanisms: Set<CryptographicMechanism>

    /// Reuses the framework-owned discovery session when it is already active.
    init(smartCard: TKSmartCard, aid: Data?, tokenDriver: TKSmartCardTokenDriver) throws {
        let channel = CardChannel(card: smartCard)
        let discovered = try smartCard.currentProtocol.rawValue != 0
            ? channel.discover() : smartCard.withSession { try channel.discover() }
        identity = discovered.identity
        let publicData = discovered.publicData
        let supportedMechanisms = publicData.info.mechanisms
        mechanisms = supportedMechanisms
        guard ECSignatureAlgorithm.allCases.contains(where: { supportedMechanisms.contains($0.mechanism) }) else {
            throw CardDataError.unsupportedSigningAlgorithms(mechanisms: supportedMechanisms)
        }
        super.init(smartCard: smartCard, aid: aid, instanceID: publicData.info.serial.hex, tokenDriver: tokenDriver)
        delegate = self

        let items: [TKTokenKeychainItem] = try publicData.certificates.map { item in
            guard let certificate = SecCertificateCreateWithData(nil, item.der as CFData),
                  let keychainItem = TKTokenKeychainCertificate(
                    certificate: certificate, objectID: "cert-\(item.reference.path.bytes.hex)-\(item.reference.path.offset)"
                  ) else { throw CardDataError.invalidX509Certificate }
            keychainItem.label = item.reference.label
            return keychainItem
        }
        guard let certificate = SecCertificateCreateWithData(nil, identity.certificate.der as CFData),
              let key = TKTokenKeychainKey(certificate: certificate, objectID: identity.objectID),
              key.keyType == (kSecAttrKeyTypeECSECPrimeRandom as String), key.keySizeInBits == 384 else {
            throw CardDataError.unsupportedAuthenticationCertificate
        }
        key.label = String(localized: .cardAuthenticationKeyLabel)
        key.canSign = true
        key.canDecrypt = false
        key.canPerformKeyExchange = false
        key.isSuitableForLogin = false
        key.constraints = [
            NSNumber(value: TKTokenOperation.signData.rawValue): identity.constraint,
            NSNumber(value: TKTokenOperation.decryptData.rawValue): false,
            NSNumber(value: TKTokenOperation.performKeyExchange.rawValue): false
        ]
        guard let contents = keychainContents else { throw CardDataError.missingTokenKeychainContents }
        contents.fill(with: items + [key])
        Logger(subsystem: "fi.myyra.AgentEID", category: "token").info("Published \(items.count) certificates and an authentication key; public-key hash length \(key.publicKeyHash?.count ?? 0)")
    }

    func createSession(_ token: TKToken) throws -> TKTokenSession { TokenSession(token: self) }
}
