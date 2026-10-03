import Foundation

/// Semantic commands; CryptoTokenKit remains responsible for APDU framing and continuation.
enum CardCommand {
    case selectApplication
    case selectFile(CardPath)
    case readBinary(offset: Int, length: Int)
    case pinStatus(reference: UInt8)
    case verifyPIN(reference: UInt8, encodedPIN: Data)
    case prepareSignature(algorithm: ECSignatureAlgorithm, keyReference: UInt8)
    case submitDigest(Data)
    case computeSignature(responseLength: Int)

    enum Instruction: UInt8 {
        case select = 0xA4
        case readBinary = 0xB0
        case verify = 0x20
        case manageSecurityEnvironment = 0x22
        case performSecurityOperation = 0x2A
    }

    enum SelectionMode: UInt8 {
        case fileID = 0x00
        case applicationID = 0x04
        case absolutePath = 0x08
        case relativePath = 0x09
    }

    enum SelectionResponse: UInt8 {
        case fileControlParameters = 0x04
        case none = 0x0C
    }

    /// P1/P2 meanings depend on the instruction; keep their interpretation together until serialization.
    enum Header {
        case select(SelectionMode, response: SelectionResponse)
        case readBinary(offset: Int)
        case verify(reference: UInt8)
        case setSigningEnvironment
        case submitDigest
        case computeSignature

        var fields: (instruction: Instruction, p1: UInt8, p2: UInt8) {
            switch self {
            case .select(let mode, let response):
                (.select, mode.rawValue, response.rawValue)
            case .readBinary(let offset):
                (.readBinary, UInt8(offset >> 8), UInt8(truncatingIfNeeded: offset))
            case .verify(let reference):
                (.verify, 0, reference)
            case .setSigningEnvironment:
                (.manageSecurityEnvironment, 0x41, 0xB6)
            case .submitDigest:
                (.performSecurityOperation, 0x90, 0xA0)
            case .computeSignature:
                (.performSecurityOperation, 0x9E, 0x9A)
            }
        }
    }

    /// Command inputs for CryptoTokenKit; PIN verification data must already be encoded and padded.
    struct Parameters {
        let header: Header
        var data: Data? = nil
        var expectedResponseLength: Int? = nil
    }

    var parameters: Parameters {
        switch self {
        case .selectApplication:
            return Parameters(header: .select(.applicationID, response: .none), data: Self.pkcs15ApplicationID)
        case .selectFile(let path):
            let absolute = path.bytes.count > 2 && path.bytes.starts(with: CardPath.File.masterFile.bytes)
            let selection = absolute ? Data(path.bytes.dropFirst(2)) : path.bytes
            let addressing: SelectionMode = path.bytes.count == 2 ? .fileID : (absolute ? .absolutePath : .relativePath)
            return Parameters(header: .select(addressing, response: .fileControlParameters),
                              data: selection, expectedResponseLength: 0)
        case .readBinary(let offset, let length):
            return Parameters(header: .readBinary(offset: offset), expectedResponseLength: length)
        case .pinStatus(let reference):
            return Parameters(header: .verify(reference: reference))
        case .verifyPIN(let reference, let encodedPIN):
            return Parameters(header: .verify(reference: reference), data: encodedPIN)
        case .prepareSignature(let algorithm, let reference):
            let payload = CardCommandPayload.algorithmReference(algorithm.reference).encoded
                + CardCommandPayload.keyReference(reference).encoded
            return Parameters(header: .setSigningEnvironment, data: payload)
        case .submitDigest(let digest):
            return Parameters(header: .submitDigest, data: CardCommandPayload.digest(digest).encoded)
        case .computeSignature(let length):
            return Parameters(header: .computeSignature, expectedResponseLength: length)
        }
    }

    private static let pkcs15ApplicationID = Data([0xA0, 0, 0, 0, 0x63]) + Data("PKCS-15".utf8)
}
