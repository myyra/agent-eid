import Combine
import CryptoTokenKit
import Foundation

/// Observes reader membership and card state; each iteration owns its KVO subscriptions.
enum ReaderObservation {
    /// Buffers transitions between awaits so removing and reinserting the same card invalidates preparation.
    static var updates: some AsyncSequence<ReaderStatus, Never> {
        let publisher: AnyPublisher<ReaderStatus, Never>
        if let manager = TKSmartCardSlotManager.default {
            publisher = manager.publisher(for: \.slotNames, options: [.initial, .new])
                .map { names in
                    snapshots(for: names.sorted().compactMap { manager.slotNamed($0) })
                }
                .switchToLatest()
                .map { ReaderStatus(readers: $0, error: nil) }
                .eraseToAnyPublisher()
        } else {
            publisher = Just(ReaderStatus(readers: [], error: String(localized: .errorsReaderAccessUnavailable)))
                .eraseToAnyPublisher()
        }
        return publisher
            .removeDuplicates()
            .buffer(size: .max, prefetch: .keepFull, whenFull: .dropOldest)
            .values
    }

    private static func snapshots(for slots: [TKSmartCardSlot]) -> AnyPublisher<[ReaderSnapshot], Never> {
        slots.reduce(Just([ReaderSnapshot]()).eraseToAnyPublisher()) { readers, slot in
            let reader = slot.publisher(for: \.state, options: [.initial, .new])
                .map { state in
                    ReaderSnapshot(name: slot.name, state: state, atr: slot.atr?.bytes)
                }
            return readers.combineLatest(reader) { $0 + [$1] }.eraseToAnyPublisher()
        }
    }
}
