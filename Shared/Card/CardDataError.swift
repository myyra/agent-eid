import Foundation

/// Preserve failure identity and diagnostic values independently of localized presentation.
enum CardDataError: Error, LocalizedError, Equatable, Sendable {
    case invalidFilePathOrRange
    case unsupportedDirectoryEntry
    case missingSerialNumber
    case missingFileSize
    case invalidFileSize
    case fileRangeExceedsSize
    case incompleteFileRead
    case recordTooLarge
    case invalidRecordLength
    case truncatedRecord
    case invalidASN1Record
    case unsupportedASN1Structure
    case invalidASN1Field
    case missingASN1Field
    case invalidPrivateKeyMetadata
    case invalidPIN(minimumLength: Int, maximumLength: Int)
    case invalidPINMetadata
    case unsupportedAuthenticationKeyProfile
    case pinNotActivated
    case invalidSignatureLength
    case zeroSignatureComponent
    case invalidDigestLength
    case unsupportedSigningAlgorithms(mechanisms: Set<CryptographicMechanism>)
    case invalidX509Certificate
    case unsupportedAuthenticationCertificate
    case missingTokenKeychainContents
    case invalidAuthenticationCertificate
    case cannotBuildCertificateChain
    case missingIssuerCertificate
    case cannotRegisterIssuerCertificate(status: Int32)
    case status(CardStatus)
    case noCard

    var errorDescription: String? {
        let detail: String
        switch self {
        case .invalidFilePathOrRange: detail = String(localized: .errorsCardDataInvalidFilePathOrRange)
        case .unsupportedDirectoryEntry: detail = String(localized: .errorsCardDataUnsupportedDirectoryEntry)
        case .missingSerialNumber: detail = String(localized: .errorsCardDataMissingSerialNumber)
        case .missingFileSize: detail = String(localized: .errorsCardDataMissingFileSize)
        case .invalidFileSize: detail = String(localized: .errorsCardDataInvalidFileSize)
        case .fileRangeExceedsSize: detail = String(localized: .errorsCardDataFileRangeExceedsSize)
        case .incompleteFileRead: detail = String(localized: .errorsCardDataIncompleteFileRead)
        case .recordTooLarge: detail = String(localized: .errorsCardDataRecordTooLarge)
        case .invalidRecordLength: detail = String(localized: .errorsCardDataInvalidRecordLength)
        case .truncatedRecord: detail = String(localized: .errorsCardDataTruncatedRecord)
        case .invalidASN1Record: detail = String(localized: .errorsCardDataInvalidAsn1Record)
        case .unsupportedASN1Structure: detail = String(localized: .errorsCardDataUnsupportedAsn1Structure)
        case .invalidASN1Field: detail = String(localized: .errorsCardDataInvalidAsn1Field)
        case .missingASN1Field: detail = String(localized: .errorsCardDataMissingAsn1Field)
        case .invalidPrivateKeyMetadata: detail = String(localized: .errorsCardDataInvalidPrivateKeyMetadata)
        case .invalidPIN(let minimumLength, let maximumLength): detail = String(localized: .errorsCardDataInvalidPin(minimumLength: minimumLength, maximumLength: maximumLength))
        case .invalidPINMetadata: detail = String(localized: .errorsCardDataInvalidPinMetadata)
        case .unsupportedAuthenticationKeyProfile: detail = String(localized: .errorsCardDataUnsupportedAuthenticationKeyProfile)
        case .pinNotActivated: detail = String(localized: .errorsCardDataPinNotActivated)
        case .invalidSignatureLength: detail = String(localized: .errorsCardDataInvalidSignatureLength)
        case .zeroSignatureComponent: detail = String(localized: .errorsCardDataZeroSignatureComponent)
        case .invalidDigestLength: detail = String(localized: .errorsCardDataInvalidDigestLength)
        case .unsupportedSigningAlgorithms(let mechanisms):
            let references = String(describing: mechanisms.map(\.rawValue).sorted())
            detail = String(localized: .errorsCardDataUnsupportedSigningAlgorithms(references: references))
        case .invalidX509Certificate: detail = String(localized: .errorsCardDataInvalidX509Certificate)
        case .unsupportedAuthenticationCertificate: detail = String(localized: .errorsCardDataUnsupportedAuthenticationCertificate)
        case .missingTokenKeychainContents: detail = String(localized: .errorsCardDataMissingTokenKeychainContents)
        case .invalidAuthenticationCertificate: detail = String(localized: .errorsCardDataInvalidAuthenticationCertificate)
        case .cannotBuildCertificateChain: detail = String(localized: .errorsCardDataCannotBuildCertificateChain)
        case .missingIssuerCertificate: detail = String(localized: .errorsCardDataMissingIssuerCertificate)
        case .cannotRegisterIssuerCertificate(let status): detail = String(localized: .errorsCardDataCannotRegisterIssuerCertificate(status: status))
        case .status(let status): return status.localizedDescription
        case .noCard: return String(localized: .errorsCardDataNoCard)
        }
        return String(localized: .errorsCardDataDescription(detail: detail))
    }
}
