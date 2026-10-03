import CryptoKit
import Foundation

enum PINMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case native
    case keychain

    var id: Self { self }
    var localizedDescription: LocalizedStringResource { self == .native ? .settingsAuthenticationMethodsNativeTitle : .settingsAuthenticationMethodsSavedPinTitle }
}

struct PINSettings: Codable, Equatable, Sendable {
    var mode: PINMode = .native
    var savedCardID: String?
}

enum SavedPIN {
    static func validate(_ data: Data) throws {
        guard (4...12).contains(data.count), data.allSatisfy({ (48...57).contains($0) }) else {
            throw PINProviderError.invalidPIN
        }
    }

    /// Use the authentication certificate to prevent a saved PIN being tried on another card.
    static func cardID(certificate: Data) -> String {
        SHA256.hash(data: certificate).map { String(format: "%02x", $0) }.joined()
    }

    static func validate(cardID: String) throws {
        guard cardID.utf8.count == 64,
              cardID.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }) else {
            throw PINProviderError.invalidCardID
        }
    }
}
