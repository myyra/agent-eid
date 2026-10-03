import Foundation
import Observation

@MainActor @Observable
final class AuthenticationSettingsModel {
    private(set) var settings = PINSettings()
    private(set) var loaded = false
    private(set) var busy = false
    private(set) var error: String?
    var loadAttempt = 0
    var isSettingUpPIN = false

    /// Reads the active method; writes request a change without selecting an unconfigured saved PIN.
    var mode: PINMode {
        get { settings.mode }
        set { selectMode(newValue) }
    }

    func load() async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        do {
            settings = try await PINProvider.loadSettings()
            loaded = true
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    func didSavePIN(_ settings: PINSettings) {
        self.settings = settings
    }

    func forgetPIN() {
        perform {
            try await PINProvider.forgetPIN()
        }
    }

    private func selectMode(_ mode: PINMode) {
        guard !busy, mode != settings.mode else { return }
        error = nil
        if mode == .keychain, settings.savedCardID == nil {
            isSettingUpPIN = true
            return
        }
        perform {
            try await PINProvider.saveMode(mode)
        }
    }

    private func perform(_ operation: @escaping @MainActor () async throws -> Void) {
        guard !busy else { return }
        error = nil
        busy = true
        Task {
            defer { busy = false }
            do {
                try await operation()
                settings = try await PINProvider.loadSettings()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}
