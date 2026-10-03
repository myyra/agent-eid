import CryptoTokenKit
import Foundation

struct ReaderStatus: Equatable, Sendable {
    let readers: [ReaderSnapshot]
    let error: String?
}

struct ReaderSnapshot: Identifiable, Equatable, Sendable {
    let name: String
    let state: TKSmartCardSlot.State
    let atr: Data?

    var id: String { name }
    var hasCard: Bool { state == .validCard }
    var localizedDescription: LocalizedStringResource {
        switch state {
        case .validCard: .menuCardStatusInserted
        case .empty: .menuCardStatusAbsent
        case .probing: .menuCardStatusDetecting
        case .muteCard: .menuCardStatusNotResponding
        case .missing: .menuReaderStatusDisconnected
        default: .menuReaderStatusUnavailable
        }
    }
}

enum ReaderService {
    /// Blocking CryptoTokenKit calls stay off the UI actor; only value snapshots cross back.
    @concurrent
    static func snapshot() async -> ReaderStatus {
        guard let manager = TKSmartCardSlotManager.default else {
            return ReaderStatus(readers: [], error: String(localized: .errorsReaderAccessUnavailable))
        }
        let readers = manager.slotNames.sorted().compactMap { name -> ReaderSnapshot? in
            guard let slot = manager.slotNamed(name) else { return nil }
            return ReaderSnapshot(name: name, state: slot.state, atr: slot.atr?.bytes)
        }
        return ReaderStatus(readers: readers, error: nil)
    }

    /// Checks PIN1 once and returns the identity from the same exclusive card session.
    /// A rejected PIN consumes a card retry; callers must not automatically repeat this operation.
    @concurrent
    static func verifyPIN(_ pin: String) async throws -> String {
        let snapshot = await snapshot()
        let cards = snapshot.readers.filter(\.hasCard)
        guard cards.count == 1, let reader = cards.first else {
            throw PINProviderError.singleCardRequired
        }
        guard let slot = TKSmartCardSlotManager.default?.slotNamed(reader.name),
              slot.state == .validCard, slot.atr?.bytes == reader.atr,
              let card = slot.makeSmartCard() else { throw CardDataError.noCard }
        return try card.withSession {
            let channel = CardChannel(card: card)
            let identity = try channel.discover().identity
            try channel.selectApplication()
            try channel.verify(pin, reference: identity.pin)
            return SavedPIN.cardID(certificate: identity.certificate.der)
        }
    }

    /// Registers the public issuer chain for browser TLS without requesting a PIN.
    @concurrent
    static func prepare(_ reader: ReaderSnapshot) async throws -> PreparedCard {
        guard let slot = TKSmartCardSlotManager.default?.slotNamed(reader.name),
              slot.state == .validCard, slot.atr?.bytes == reader.atr,
              let card = slot.makeSmartCard() else { throw CardDataError.noCard }
        let discovery = try card.withSession { try CardChannel(card: card).discover() }
        let data = discovery.publicData
        let identity = discovery.identity
        try BrowserCertificateChain.register(identity: identity, publicData: data)
        return try PreparedCard(authenticationCertificate: identity.certificate.der)
    }
}
