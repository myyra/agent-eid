import CryptoTokenKit
import Foundation

/// A grant is scoped to CryptoTokenKit's card context, which the system clears on reset
/// or access by another client. Signing consumes it even when the card retains PIN state.
final class AuthenticationGrant: NSObject {
    let constraint: String
    init(constraint: String) { self.constraint = constraint }
}

/// Preserve card failure details while mapping them to CryptoTokenKit authentication semantics.
func tokenError(_ error: Error) -> Error {
    guard let cardError = error as? CardDataError else { return error }
    let code: TKError.Code
    switch cardError {
    case .status(.authenticationRequired): code = .authenticationNeeded
    case .status(.pinBlocked), .status(.pinNotInitialized): code = .authenticationFailed
    case .status(.verificationFailed): code = .authenticationFailed
    case .noCard: code = .tokenNotFound
    default: code = .corruptedData
    }
    return NSError(domain: TKErrorDomain, code: code.rawValue,
                   userInfo: [NSLocalizedDescriptionKey: cardError.localizedDescription])
}

/// macOS collects PIN1. One explicit VERIFY is sent; the PIN is never logged or cached.
final class PINOperation: TKTokenSmartCardPINAuthOperation {
    private let card: TKSmartCard
    private let identity: AuthenticationIdentity

    init(card: TKSmartCard, identity: AuthenticationIdentity) {
        self.card = card
        self.identity = identity
        super.init()
        pinFormat.charset = .numeric
        pinFormat.encoding = .ascii
        pinFormat.minPINLength = identity.pin.minimumLength
        pinFormat.maxPINLength = identity.pin.maximumLength
        pinFormat.pinBlockByteLength = identity.pin.storedLength
    }

    required init?(coder: NSCoder) { return nil }

    override func finish() throws {
        defer { pin = nil }
        guard let pin else {
            throw NSError(domain: TKErrorDomain, code: TKError.Code.canceledByUser.rawValue)
        }
        try authenticate(pin: pin, card: card, identity: identity)
    }
}

/// Obtain PIN1 for this pending request without asking macOS to display its PIN dialog.
/// Failures cancel the request so the system cannot automatically retry a wrong PIN.
final class KeychainPINOperation: TKTokenAuthOperation {
    private let card: TKSmartCard
    private let identity: AuthenticationIdentity

    init(card: TKSmartCard, identity: AuthenticationIdentity) {
        self.card = card
        self.identity = identity
        super.init()
    }

    required init?(coder: NSCoder) { return nil }

    override func finish() throws {
        card.context = nil
        do {
            try authenticate(pin: PINProvider.obtainPIN(cardID: SavedPIN.cardID(certificate: identity.certificate.der)),
                             card: card, identity: identity)
        } catch let error as PINProviderError {
            throw NSError(domain: TKErrorDomain, code: TKError.Code.canceledByUser.rawValue,
                          userInfo: [NSLocalizedDescriptionKey: error.localizedDescription])
        } catch {
            let failure = error as NSError
            if failure.domain == TKErrorDomain,
               failure.code == TKError.Code.authenticationFailed.rawValue {
                throw NSError(domain: TKErrorDomain, code: TKError.Code.canceledByUser.rawValue,
                              userInfo: failure.userInfo)
            }
            throw error
        }
    }
}

private func authenticate(pin: String, card: TKSmartCard, identity: AuthenticationIdentity) throws {
    card.context = nil
    do {
        try CardChannel(card: card).verify(pin, reference: identity.pin)
        card.context = AuthenticationGrant(constraint: identity.constraint)
    } catch {
        throw tokenError(error)
    }
}
