import Foundation
import Security

enum PINProviderError: Error, LocalizedError, Equatable, Sendable {
    case invalidPIN
    case invalidCardID
    case savedPINRequired
    case settingsChanged
    case noSavedPIN
    case authenticationNotEnabledForCard
    case invalidStoredPIN
    case missingAccessGroup
    case invalidStoredSettings
    case singleCardRequired
    case keychain(status: OSStatus)

    var errorDescription: String? {
        switch self {
        case .invalidPIN: return String(localized: .errorsPinProviderInvalidPin)
        case .invalidCardID: return String(localized: .errorsPinProviderInvalidCardId)
        case .savedPINRequired: return String(localized: .errorsPinProviderSavedPinRequired)
        case .settingsChanged: return String(localized: .errorsPinProviderSettingsChanged)
        case .noSavedPIN: return String(localized: .errorsPinProviderNoSavedPin)
        case .authenticationNotEnabledForCard: return String(localized: .errorsPinProviderAuthenticationNotEnabledForCard)
        case .invalidStoredPIN: return String(localized: .errorsPinProviderInvalidStoredPin)
        case .missingAccessGroup: return String(localized: .errorsPinProviderMissingAccessGroup)
        case .invalidStoredSettings: return String(localized: .errorsPinProviderInvalidStoredSettings)
        case .singleCardRequired: return String(localized: .errorsPinProviderSingleCardRequired)
        case .keychain(let status):
            let detail = SecCopyErrorMessageString(status, nil) as String? ?? String(localized: .errorsSystemStatus(status: status))
            return String(localized: .errorsKeychainDescription(detail: detail))
        }
    }
}
