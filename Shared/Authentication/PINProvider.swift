import Foundation

enum PINProvider {
    static func loadSettings() async throws -> PINSettings {
        try await offload { try KeychainPINStore().settings() }
    }

    static func saveMode(_ mode: PINMode) async throws {
        try await offload { try KeychainPINStore().saveMode(mode) }
    }

    static func savePIN(_ pin: String, cardID: String) async throws {
        let data = Data(pin.utf8)
        try await offload { try KeychainPINStore().save(data, cardID: cardID) }
    }

    static func forgetPIN() async throws {
        try await offload { try KeychainPINStore().forget() }
    }

    static func authenticationMode() throws -> PINMode {
        try KeychainPINStore().settings().mode
    }

    static func obtainPIN(cardID: String) throws -> String {
        let data = try KeychainPINStore().pin(for: cardID)
        return String(decoding: data, as: UTF8.self)
    }

    /// Keychain can wait for system UI. Keep that blocking work off the main actor
    /// and cooperative pool; CryptoTokenKit uses synchronous methods on its threads.
    /// Operations run to completion: task cancellation cannot undo a Keychain write.
    private static func offload<T: Sendable>(_ operation: @escaping @Sendable () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do { continuation.resume(returning: try operation()) }
                catch { continuation.resume(throwing: error) }
            }
        }
    }
}
