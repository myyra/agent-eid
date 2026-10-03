import CryptoTokenKit
import Foundation
import Observation

@MainActor @Observable
final class ReaderModel {
    private(set) var status = ReaderStatus(readers: [], error: nil)
    private var preparations: [String: Preparation] = [:]
    @ObservationIgnored private var isPreparing = false

    private struct Preparation {
        let reader: ReaderSnapshot
        let result: Result<PreparedCard, any Error>
    }

    /// With multiple readers, a ready card takes precedence over individual reader failures.
    var menuBarSymbol: SystemSymbol {
        let readers = status.readers
        if status.error != nil { return .identityCardError }
        if readers.contains(where: isReady(for:)) { return .identityCardFilled }
        if readers.contains(where: { error(for: $0) != nil || $0.state == .muteCard }) {
            return .identityCardError
        }
        return .identityCard
    }

    var menuBarStatus: String {
        if let error = status.error { return error }
        guard !status.readers.isEmpty else { return String(localized: .menuReadersConnectTitle) }
        return status.readers.map { reader in
            error(for: reader) ?? String(localized: localizedDescription(for: reader))
        }.joined(separator: ". ")
    }

    func localizedDescription(for reader: ReaderSnapshot) -> LocalizedStringResource {
        guard reader.hasCard else { return reader.localizedDescription }
        if let preparation = preparations[reader.name] {
            switch preparation.result {
            case .success: return .menuCardStatusReady
            case .failure: return .menuCardStatusPreparationFailed
            }
        }
        return .menuCardStatusPreparing
    }

    func isReady(for reader: ReaderSnapshot) -> Bool {
        guard case .success = preparations[reader.name]?.result else { return false }
        return true
    }

    func holderName(for reader: ReaderSnapshot) -> String? {
        guard case .success(let card) = preparations[reader.name]?.result else { return nil }
        return card.holderName
    }

    func error(for reader: ReaderSnapshot) -> String? {
        guard case .failure(let error) = preparations[reader.name]?.result else { return nil }
        return error.localizedDescription
    }

    func retry(_ reader: ReaderSnapshot) {
        preparations[reader.name] = nil
        prepareNextCard()
    }

    func monitor() async {
        for await snapshot in ReaderObservation.updates {
            update(snapshot)
        }
    }

    private func update(_ snapshot: ReaderStatus) {
        guard snapshot != status else { return }
        status = snapshot
        preparations = preparations.filter { snapshot.readers.contains($0.value.reader) }
        prepareNextCard()
    }

    private func prepareNextCard() {
        guard !isPreparing,
              let reader = status.readers.first(where: { $0.hasCard && preparations[$0.name] == nil }) else { return }
        isPreparing = true
        Task {
            defer {
                isPreparing = false
                prepareNextCard()
            }
            let result: Result<PreparedCard, any Error>
            do {
                result = .success(try await ReaderService.prepare(reader))
            } catch {
                result = .failure(error)
            }
            if status.readers.contains(reader) {
                preparations[reader.name] = Preparation(reader: reader, result: result)
            }
        }
    }
}
