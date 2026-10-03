import Foundation
import Testing
import SwiftASN1
@testable import AgentEID

struct CardDataTests {
    @Test
    func readsDirectoryPathsAndPadding() throws {
        let data = Data([
            0, 0xA4, 8, 0x30, 6, 4, 4, 0x3F, 0, 0x44, 3, 0, 0xFF,
            0xA8, 6, 0x30, 4, 4, 2, 0x44, 4, 0xFF
        ])
        let entries = try CardDirectory.decode(data)
        #expect(entries == [
            CardDirectory(kind: .certificates, path: try CardPath(bytes: Data([0x3F, 0, 0x44, 3]))),
            CardDirectory(kind: .authenticationObjects, path: try CardPath(bytes: Data([0x44, 4])))
        ])
    }

    @Test
    func readsCertificateReference() throws {
        let data = Data([
            0x30, 24,
            0x30, 6, 0x0C, 4, 0x41, 0x75, 0x74, 0x68,
            0x30, 3, 4, 1, 0x45,
            0xA1, 9, 0x30, 7, 0x30, 5, 4, 3, 0x3F, 0, 0x43
        ])
        #expect(throws: CardDataError.self) { try CertificateReference.decode(data) }
        let valid = Data([
            0x30, 25,
            0x30, 6, 0x0C, 4, 0x41, 0x75, 0x74, 0x68,
            0x30, 3, 4, 1, 0x45,
            0xA1, 10, 0x30, 8, 0x30, 6, 4, 4, 0x3F, 0, 0x43, 0x31
        ])
        let reference = try #require(CertificateReference.decode(valid).first)
        #expect(reference.id == Data([0x45]))
        #expect(reference.label == "Auth")
        #expect(reference.path.bytes == Data([0x3F, 0, 0x43, 0x31]))
    }

    @Test
    func readsCardInfoWithoutAssumingSerialEncoding() throws {
        let info = try CardInfo.decode(Data([
            0x30, 13, 2, 1, 1, 4, 3, 0x39, 0x4A, 0x31, 0x80, 3, 0x49, 0x44, 0x21
        ]))
        #expect(info.serial == Data([0x39, 0x4A, 0x31]))
        #expect(info.label == "ID!")
    }

    @Test(arguments: [
        Data([0x30]), Data([0x30, 0x80]), Data([0x30, 4, 2, 1, 1]),
        Data([0x04, 0x82, 1]), Data([0x1F, 0]),
        Data([0x30, 0x80, 0, 0]), Data([0x30, 4, 0x30, 0x80, 0, 0]),
        Data([0x30, 2, 4, 1, 4, 1, 0xAA])
    ])
    func rejectsMalformedBER(_ data: Data) {
        #expect(throws: CardDataError.self) { try CardASN1.records(data) }
    }

    @Test(arguments: [(128, Data([0x81, 0x80])), (256, Data([0x82, 1, 0]))])
    func readsLongLengthsAndEnforcesSizeLimit(_ count: Int, _ length: Data) throws {
        let value = Data(repeating: 0xAA, count: count)
        let node = try #require(CardASN1.records(Data([4]) + length + value).first)
        #expect(Data(try ASN1OctetString(berEncoded: node).bytes) == value)
        #expect(throws: CardDataError.self) {
            try CardASN1.records(Data(repeating: 0, count: 1_048_576))
        }
    }

    @Test
    func rejectsExcessiveNesting() {
        var bytes = Data([4, 0])
        for _ in 0..<16 {
            bytes = Data([0x30, UInt8(bytes.count)]) + bytes
        }
        #expect(throws: CardDataError.self) { try CardASN1.records(bytes) }
    }

    @Test(arguments: [
        (Data([0x80]), 128), (Data([0x80, 0]), 32_768),
        (Data([0x80, 0, 0]), 8_388_608), (Data([0xFF, 0xFF, 0xFF, 0xFF]), 4_294_967_295)
    ])
    func distinguishesUnsignedFileSizesFromASN1Integers(_ bytes: Data, _ expected: Int) throws {
        let node = try BER.parse([0x80, UInt8(bytes.count)] + bytes)
        #expect(try node.fileSize() == expected)
        let path = Data([4, 2, 0x43, 0x31, 2, UInt8(bytes.count)]) + bytes
        let record = Data([0xA4, UInt8(path.count + 2), 0x30, UInt8(path.count)]) + path
        #expect(throws: CardDataError.self) { try CardDirectory.decode(record) }
    }

    @Test
    func validatesFileRanges() throws {
        let node = try #require(CardASN1.records(Data([
            0x30, 10, 4, 2, 0x43, 0x31, 2, 1, 5, 0x80, 1, 10
        ])).first)
        let path = try CardPath(berEncoded: node)
        #expect(path.offset == 5)
        #expect(path.length == 10)
        #expect(throws: CardDataError.self) {
            try CardPath(bytes: Data([0x43, 0x31]), offset: 32_760, length: 20)
        }
    }
}

struct CardSigningTests {
    private let pin = PINReference(id: Data([1]), reference: 0x11, minimumLength: 4,
                                   maximumLength: 12, storedLength: 12, padding: 0,
                                   initialized: true, numericASCII: true)

    @Test(arguments: ["", "123", "1234567890123", "12a4", "１２３４"])
    func rejectsInvalidPINWithoutContactingCard(_ input: String) {
        let transport = RecordingTransport()
        #expect(throws: CardDataError.invalidPIN(minimumLength: 4, maximumLength: 12)) {
            try CardChannel(transport: transport).verify(input, reference: pin)
        }
        #expect(transport.commands.isEmpty)
    }

    @Test(arguments: [(UInt16(0x63C0), 0), (UInt16(0x63C2), 2), (UInt16(0x63CF), 15)])
    func failedPINIsSentOnceAndReportsRemainingRetries(_ statusWord: UInt16, _ attempts: Int) {
        let transport = RecordingTransport(responses: [CardResponse(sw: statusWord, response: Data())])
        do {
            try CardChannel(transport: transport).verify("1234", reference: pin)
            Issue.record("Expected a PIN failure")
        } catch CardDataError.status(let status) {
            #expect(status == .verificationFailed(retriesRemaining: attempts))
        } catch { Issue.record("Unexpected error: \(error)") }
        #expect(transport.commands.count == 1)
        #expect(transport.commands.first?.data == Data([0x31, 0x32, 0x33, 0x34]) + Data(repeating: 0, count: 8))
    }

    @Test
    func preservesUnrecognizedCardFailures() {
        let transport = RecordingTransport(responses: [CardResponse(sw: 0x6F42, response: Data())])
        do {
            try CardChannel(transport: transport).verify("1234", reference: pin)
            Issue.record("Expected a card failure")
        } catch {
            #expect(error as? CardDataError == .status(.unknown(0x6F42)))
        }
        #expect(transport.commands.count == 1)
    }

    @Test
    func statusQueryContainsNoPIN() throws {
        let transport = RecordingTransport(responses: [CardResponse(sw: 0x63C3, response: Data())])
        #expect(try CardChannel(transport: transport).pinStatus(pin) == .verificationFailed(retriesRemaining: 3))
        let command = try #require(transport.commands.first)
        #expect(transport.commands.count == 1)
        #expect(command.ins == 0x20)
        #expect(command.p1 == 0 && command.p2 == 0x11)
        #expect(command.data?.isEmpty != false)
    }

    @Test(arguments: ECSignatureAlgorithm.allCases)
    func sendsDigestUnchangedAndSelectsItsAlgorithm(_ algorithm: ECSignatureAlgorithm) throws {
        let parameters: (length: Int, reference: UInt8) = switch algorithm {
        case .sha256: (32, 0x44)
        case .sha384: (48, 0x54)
        case .sha512: (64, 0x64)
        }
        let digest = Data(repeating: 0xAA, count: parameters.length)
        let raw = Data(repeating: 1, count: 96)
        let transport = RecordingTransport(responses: [
            CardResponse(sw: 0x9000, response: Data()), CardResponse(sw: 0x9000, response: Data()),
            CardResponse(sw: 0x9000, response: raw)
        ])
        let identity = AuthenticationIdentity(
            key: PrivateKeyReference(id: Data([0x45]), authID: Data([1]), reference: 1,
                                     canSign: true, curve: ASN1ObjectIdentifier.NamedCurves.secp384r1, path: Data()),
            pin: pin,
            certificate: PublicCertificate(reference: CertificateReference(id: Data([0x45]), label: "Auth",
                path: try CardPath(bytes: Data([0x43, 0x31]))), der: Data())
        )
        _ = try CardChannel(transport: transport).sign(digest, identity: identity, algorithm: algorithm)
        #expect(transport.commands == [
            Command(ins: 0x22, p1: 0x41, p2: 0xB6, data: Data([0x80, 1, parameters.reference, 0x84, 1, 1]), le: nil),
            Command(ins: 0x2A, p1: 0x90, p2: 0xA0, data: Data([0x90, UInt8(digest.count)]) + digest, le: nil),
            Command(ins: 0x2A, p1: 0x9E, p2: 0x9A, data: nil, le: 96)
        ])
    }

    @Test
    func DEREncodesLongSequenceLengths() throws {
        let component = Data(repeating: 0x80, count: 66)
        let expected = Data([0x30, 0x81, 0x8A, 2, 0x43, 0]) + component
            + Data([2, 0x43, 0]) + component
        #expect(try ECDSASignature.der(component + component, coordinateLength: 66) == expected)
    }

    @Test
    func DERUsesPositiveMinimalIntegers() throws {
        let raw = Data([0, 0, 0x80, 1, 0, 0, 0, 2])
        #expect(try ECDSASignature.der(raw, coordinateLength: 4) == Data([0x30, 8, 2, 3, 0, 0x80, 1, 2, 1, 2]))
        #expect(throws: CardDataError.self) { try ECDSASignature.der(Data(repeating: 0, count: 96), coordinateLength: 48) }
        #expect(throws: CardDataError.self) { try ECDSASignature.der(Data([1]), coordinateLength: 48) }
    }
}

struct CardFileReadingTests {
    @Test(arguments: [
        (Data([0x50, 0x32]), UInt8(0x00), Data([0x50, 0x32])),
        (Data([0x3F, 0, 0x50, 0x15, 0x50, 0x32]), UInt8(0x08), Data([0x50, 0x15, 0x50, 0x32])),
        (Data([0x50, 0x15, 0x50, 0x32]), UInt8(0x09), Data([0x50, 0x15, 0x50, 0x32]))
    ])
    func selectsPathsAndReadsAcrossOffsetBoundary(_ path: Data, _ addressing: UInt8, _ selection: Data) throws {
        let firstChunk = Data(repeating: 0xAB, count: 255)
        let lastChunk = Data([0xCD])
        let transport = RecordingTransport(responses: [
            CardResponse(sw: 0x9000, response: Data([0x62, 4, 0x80, 2, 1, 1])),
            CardResponse(sw: 0x9000, response: firstChunk),
            CardResponse(sw: 0x9000, response: lastChunk)
        ])
        let output = try CardChannel(transport: transport).readFile(CardPath(bytes: path, offset: 1, length: 256))
        #expect(output == firstChunk + lastChunk)
        #expect(transport.commands == [
            Command(ins: 0xA4, p1: addressing, p2: 0x04, data: selection, le: 0),
            Command(ins: 0xB0, p1: 0, p2: 1, data: nil, le: 255),
            Command(ins: 0xB0, p1: 1, p2: 0, data: nil, le: 1)
        ])
    }
}

private struct Command: Equatable {
    let ins: UInt8
    let p1: UInt8
    let p2: UInt8
    let data: Data?
    let le: Int?
}

private final class RecordingTransport: CardTransport {
    var commands: [Command] = []
    var responses: [CardResponse]

    init(responses: [CardResponse] = []) { self.responses = responses }

    func send(ins: UInt8, p1: UInt8, p2: UInt8, data: Data?, le: Int?) throws -> CardResponse {
        commands.append(Command(ins: ins, p1: p1, p2: p2, data: data, le: le))
        guard !responses.isEmpty else { throw CardDataError.noCard }
        return responses.removeFirst()
    }
}

struct AuthenticationMetadataTests {
    private func tlv(_ tag: UInt8, _ value: Data) -> Data { Data([tag, UInt8(value.count)]) + value }
    private func number(_ value: UInt8, tag: UInt8 = 2) -> Data { tlv(tag, Data([value])) }

    @Test(arguments: [false, true])
    func decodesAuthenticationKeyAndNumericPIN(_ extendedMetadata: Bool) throws {
        let (key, pin) = try authenticationRecords(extendedMetadata: extendedMetadata)
        #expect(key.canSign)
        #expect(key.reference == 1)
        let expectedCurve: ASN1ObjectIdentifier = [1, 3, 132, 0, 34]
        #expect(key.curve == expectedCurve)
        #expect(pin.initialized)
        #expect(pin.numericASCII)
        #expect(pin.id == key.authID)
        #expect(try pin.encode("1234") == Data([49, 50, 51, 52]) + Data(repeating: 0, count: 8))
    }

    @Test
    func refusesAmbiguousAuthenticationKeys() throws {
        let (key, pin) = try authenticationRecords()
        let certificate = PublicCertificate(reference: CertificateReference(
            id: key.id, label: "Auth", path: try CardPath(bytes: Data([0x43, 0x31]))
        ), der: Data([1]))
        let publicData = PublicCardData(info: CardInfo(serial: Data([1]), label: "Card", mechanisms: []),
                                        certificates: [certificate])
        _ = try AuthenticationProfile.identity(publicData: publicData, keys: [key], pins: [pin])
        #expect(throws: CardDataError.self) {
            try AuthenticationProfile.identity(publicData: publicData, keys: [key, key], pins: [pin])
        }
    }

    private func authenticationRecords(extendedMetadata: Bool = false) throws -> (PrivateKeyReference, PINReference) {
        let objectPrefix = extendedMetadata ? tlv(0x0C, Data("Auth".utf8)) + tlv(3, Data([0, 0x40])) : Data()
        let objectSuffix = extendedMetadata ? tlv(0x30, Data()) : Data()
        let keyFlags = extendedMetadata ? tlv(1, Data([0xFF])) + tlv(3, Data([4, 0xF0])) : Data()
        let keyDates = extendedMetadata ? tlv(0x18, Data("20260101000000Z".utf8)) : Data()
        let subclass = extendedMetadata ? tlv(0xA0, Data()) : Data()
        let keyRecord = tlv(0xA0,
            tlv(0x30, objectPrefix + tlv(4, Data([1])) + number(1) + objectSuffix) +
            tlv(0x30, tlv(4, Data([0x45])) + tlv(3, Data([5, 0x20])) + keyFlags + number(1) + keyDates) +
            subclass +
            tlv(0xA1, tlv(0x30, tlv(0x30, tlv(4, Data())) + tlv(6, Data([0x2B, 0x81, 4, 0, 0x22]))))
        )
        let key = try #require(PrivateKeyReference.decode(keyRecord).first)
        let maximumLength = extendedMetadata ? Data() : number(12)
        let pinRecord = tlv(0x30,
            tlv(0x30, Data()) + tlv(0x30, tlv(4, Data([1]))) +
            tlv(0xA1, tlv(0x30, tlv(3, Data([0, 8])) + number(1, tag: 0x0A) +
                number(4) + number(12) + maximumLength + number(0x11, tag: 0x80) + tlv(4, Data([0])) + keyDates))
        )
        let pin = try #require(PINReference.decode(pinRecord).first)
        return (key, pin)
    }

    @Test(arguments: [Data([6, 0x40]), Data([0, 0x60, 0x80])])
    func selectsOnlySignatureMechanismsFromCIAInfo(_ signatureUsage: Data) throws {
        let sign = tlv(0x30, number(19) + tlv(2, Data([0x10, 0x45])) + tlv(5, Data()) + tlv(3, signatureUsage))
        let decipher = tlv(0x30, number(20) + tlv(2, Data([0x10, 0x46])) + tlv(5, Data()) + tlv(3, Data([5, 0x20])))
        let info = try CardInfo.decode(tlv(0x30, number(1) + tlv(4, Data([1])) + tlv(0xA2, sign + decipher)))
        #expect(info.mechanisms.map(\.rawValue) == [4165])
    }
}
