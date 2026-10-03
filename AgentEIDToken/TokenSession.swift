import CryptoTokenKit

/// Bridges Security digest-signing requests to the card, requiring a fresh grant for each signature.
final class TokenSession: TKSmartCardTokenSession, TKTokenSessionDelegate {
    private let identity: AuthenticationIdentity
    private let mechanisms: Set<CryptographicMechanism>

    init(token: Token) {
        identity = token.identity
        mechanisms = token.mechanisms
        super.init(token: token)
        delegate = self
    }

    private func activeCard() throws -> TKSmartCard {
        if #available(macOS 26, *) { return try getSmartCard() }
        return smartCard
    }

    func tokenSession(
        _ session: TKTokenSession, supports operation: TKTokenOperation,
        keyObjectID: Any, algorithm: TKTokenKeyAlgorithm
    ) -> Bool {
        operation == .signData && (keyObjectID as? String) == identity.objectID
            && ECSignatureAlgorithm.supports(algorithm, mechanisms: mechanisms)
    }

    func tokenSession(
        _ session: TKTokenSession, beginAuthFor operation: TKTokenOperation, constraint: Any
    ) throws -> TKTokenAuthOperation {
        guard operation == .signData, (constraint as? String) == identity.constraint else {
            throw NSError(domain: TKErrorDomain, code: TKError.Code.badParameter.rawValue)
        }
        let card = try activeCard()
        let status = try CardChannel(card: card).pinStatus(identity.pin)
        switch status {
        case .success, .verificationFailed: break
        default: throw tokenError(CardDataError.status(status))
        }

        do {
            if try PINProvider.authenticationMode() == .keychain {
                return KeychainPINOperation(card: card, identity: identity)
            }
            return PINOperation(card: card, identity: identity)
        } catch {
            throw NSError(domain: TKErrorDomain, code: TKError.Code.canceledByUser.rawValue,
                          userInfo: [NSLocalizedDescriptionKey: error.localizedDescription])
        }
    }

    func tokenSession(
        _ session: TKTokenSession, sign dataToSign: Data, keyObjectID: Any, algorithm: TKTokenKeyAlgorithm
    ) throws -> Data {
        guard (keyObjectID as? String) == identity.objectID,
              let signing = ECSignatureAlgorithm.resolve(algorithm, digestLength: dataToSign.count),
              mechanisms.contains(signing.mechanism) else {
            throw NSError(domain: TKErrorDomain, code: TKError.Code.notImplemented.rawValue)
        }
        let card = try activeCard()
        guard let grant = card.context as? AuthenticationGrant, grant.constraint == identity.constraint else {
            throw NSError(domain: TKErrorDomain, code: TKError.Code.authenticationNeeded.rawValue)
        }
        card.context = nil
        do {
            return try CardChannel(card: card).sign(dataToSign, identity: identity, algorithm: signing)
        } catch {
            throw tokenError(error)
        }
    }
}
