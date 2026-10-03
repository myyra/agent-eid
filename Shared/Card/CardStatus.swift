import Foundation

/// Decodes SW1/SW2 once, preserving unrecognized statuses and the card's PIN retry count.
enum CardStatus: Equatable, Sendable {
    case success
    case fileNotFound
    case authenticationRequired
    case pinNotInitialized
    case pinBlocked
    case verificationFailed(retriesRemaining: Int)
    case unknown(UInt16)

    init(rawValue: UInt16) {
        switch rawValue {
        case 0x9000: self = .success
        case 0x6A82: self = .fileNotFound
        case 0x6982: self = .authenticationRequired
        case 0x6984: self = .pinNotInitialized
        case 0x6983: self = .pinBlocked
        case 0x63C0...0x63CF: self = .verificationFailed(retriesRemaining: Int(rawValue & 0x000F))
        default: self = .unknown(rawValue)
        }
    }

    var localizedDescription: String {
        switch self {
        case .success: String(localized: .errorsCardStatusSuccess)
        case .fileNotFound: String(localized: .errorsCardStatusFileNotFound)
        case .authenticationRequired: String(localized: .errorsCardStatusAuthenticationRequired)
        case .pinNotInitialized: String(localized: .errorsCardStatusPinNotInitialized)
        case .pinBlocked: String(localized: .errorsCardStatusPinBlocked)
        case .verificationFailed(let attempts): String(localized: .errorsCardStatusVerificationFailed(attempts: attempts))
        case .unknown(let rawValue): String(localized: .errorsCardStatusUnknown(status: String(format: "%04X", rawValue)))
        }
    }
}
