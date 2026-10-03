import CryptoTokenKit
import Foundation
import SwiftASN1

/// Commands operate within an existing exclusive smart-card session.
struct CardChannel {
    private let transport: any CardTransport

    init(card: TKSmartCard) { transport = SmartCardTransport(card: card) }
    init(transport: any CardTransport) { self.transport = transport }

    /// Sends once and leaves status interpretation to the caller, including non-success responses.
    func send(_ command: CardCommand) throws -> CardResponse {
        let parameters = command.parameters
        let header = parameters.header.fields
        return try transport.send(ins: header.instruction.rawValue, p1: header.p1, p2: header.p2,
                                  data: parameters.data, le: parameters.expectedResponseLength)
    }

    func selectApplication() throws {
        let result = try send(.selectApplication)
        try requireSuccess(result)
    }

    /// Uses the selected file's FCP length so EOF warnings never discard partial reads.
    func readFile(_ path: CardPath) throws -> Data {
        let result = try send(.selectFile(path))
        try requireSuccess(result)
        let records = try CardASN1.records(result.response)
        guard let sizeNode = records.lazy.compactMap({ $0.first(identifier: .init(tagWithNumber: 0, tagClass: .contextSpecific)) }).first
            ?? records.lazy.compactMap({ $0.first(identifier: .init(tagWithNumber: 1, tagClass: .contextSpecific)) }).first else {
            throw CardDataError.missingFileSize
        }
        let size = try sizeNode.fileSize()
        if size == 0, path.offset == 0, path.length == nil { return Data() }
        guard size > 0, size <= 32_768, path.offset < size else {
            throw CardDataError.invalidFileSize
        }
        let count = path.length ?? (size - path.offset)
        guard count <= size - path.offset else {
            throw CardDataError.fileRangeExceedsSize
        }
        var output = Data()
        while output.count < count {
            let offset = path.offset + output.count
            let length = min(255, count - output.count)
            let response = try send(.readBinary(offset: offset, length: length))
            guard response.status == .success else { throw CardDataError.status(response.status) }
            guard response.response.count == length else {
                throw CardDataError.incompleteFileRead
            }
            output.append(response.response)
        }
        return output
    }

    /// Reads public metadata and certificates without verifying a PIN.
    /// Each phase reselects the application because certificate paths may change the current directory.
    func discover() throws -> CardDiscovery {
        try selectApplication()
        let info = try CardInfo.decode(readFile(CardPath(file: .cardInfo)))
        let directories = try CardDirectory.decode(readFile(CardPath(file: .objectDirectory)))
        let publicData = PublicCardData(info: info, certificates: try readCertificates(directories))

        try selectApplication()
        var keys: [PrivateKeyReference] = []
        var pins: [PINReference] = []
        for directory in directories {
            switch directory.kind {
            case .privateKeys: keys += try PrivateKeyReference.decode(readFile(directory.path))
            case .authenticationObjects: pins += try PINReference.decode(readFile(directory.path))
            default: break
            }
        }
        return CardDiscovery(
            publicData: publicData,
            identity: try AuthenticationProfile.identity(publicData: publicData, keys: keys, pins: pins)
        )
    }

    private func readCertificates(_ directories: [CardDirectory]) throws -> [PublicCertificate] {
        var certificates: [PublicCertificate] = []
        for directory in directories where directory.kind == .certificates || directory.kind == .trustedCertificates {
            for reference in try CertificateReference.decode(readFile(directory.path)) {
                certificates.append(PublicCertificate(reference: reference, der: try readFile(reference.path)))
            }
        }
        return certificates
    }
}

struct PublicCertificate: Sendable {
    let reference: CertificateReference
    let der: Data
}

/// Public card contents collected before authentication; discovery does not imply certificate trust.
struct PublicCardData: Sendable {
    let info: CardInfo
    let certificates: [PublicCertificate]
}

/// Public contents plus the single supported identity selected from the card directories.
struct CardDiscovery: Sendable {
    let publicData: PublicCardData
    let identity: AuthenticationIdentity
}
