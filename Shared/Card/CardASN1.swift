import BinaryParsing
import Foundation
import SwiftASN1

/// FINeID files contain definite-length BER records separated by 00 or FF padding.
/// SwiftASN1 parses each record; this adapter supplies file framing and profile limits.
enum CardASN1 {
    static func records(_ data: Data) throws -> [ASN1Node] {
        guard data.count <= 32_768 else {
            throw CardDataError.recordTooLarge
        }
        do {
            return try data.withParserSpan { input in
                var records: [ASN1Node] = []
                while !input.isEmpty {
                    var header = ParserSpan(input.bytes)
                    let tag = try UInt8(parsing: &header)
                    if tag == 0 || tag == 0xFF {
                        try input.seek(toRelativeOffset: 1)
                        continue
                    }
                    let firstLength = try UInt8(parsing: &header)
                    let length: Int
                    if firstLength < 0x80 {
                        length = Int(firstLength)
                    } else {
                        let byteCount = Int(firstLength & 0x7F)
                        guard (1...2).contains(byteCount) else {
                            throw CardDataError.invalidRecordLength
                        }
                        length = Int(try UInt16(parsingBigEndian: &header, byteCount: byteCount))
                    }
                    var record = try input.sliceSpan(byteCount: input.count - header.count + length)
                    let node = try BER.parse(Array(Data(parsingRemainingBytes: &record)))
                    try validate(node)
                    records.append(node)
                }
                return records
            }
        } catch is ParsingError {
            throw CardDataError.truncatedRecord
        } catch is ASN1Error {
            throw CardDataError.invalidASN1Record
        }
    }

    private static func validate(_ node: ASN1Node, depth: Int = 0) throws {
        guard depth < 16, node.identifier.tagNumber < 31,
              node.encodedBytes.dropFirst().first != 0x80 else {
            throw CardDataError.unsupportedASN1Structure
        }
        guard case .constructed(let children) = node.content else { return }
        for child in children {
            try validate(child, depth: depth + 1)
        }
    }
}

/// DER records use the same card schema as BER records.
protocol CardRecord: BERParseable {}

extension CardRecord {
    init(derEncoded node: ASN1Node) throws { try self.init(berEncoded: node) }
}

/// Decode framed records and translate ASN.1 field failures into the shared card error type.
func parseCardRecords<Record: CardRecord>(_ data: Data, as: Record.Type) throws -> [Record] {
    do {
        return try CardASN1.records(data).map { try Record(berEncoded: $0) }
    } catch is ASN1Error {
        throw CardDataError.invalidASN1Field
    }
}

extension ASN1Node {
    func first(identifier: ASN1Identifier) -> ASN1Node? {
        if self.identifier == identifier { return self }
        guard case .constructed(let children) = content else { return nil }
        for child in children {
            if let match = child.first(identifier: identifier) { return match }
        }
        return nil
    }

    /// FCP file sizes are raw unsigned bytes, rather than ASN.1 signed INTEGERs.
    func fileSize() throws -> Int {
        guard case .primitive(let bytes) = content, (1...4).contains(bytes.count) else {
            throw CardDataError.invalidFileSize
        }
        return Int(try UInt32(berIntegerBytes: bytes))
    }

}

extension ASN1NodeCollection.Iterator {
    mutating func nextRequired() throws -> ASN1Node {
        guard let node = next() else { throw CardDataError.missingASN1Field }
        return node
    }

    /// Consume attributes outside our supported profile so BER.sequence still checks required fields.
    mutating func discardRemaining() { while next() != nil {} }
}

extension ASN1BitString {
    /// ASN.1 numbers flags from the first byte's most significant bit; OptionSet uses bit zero.
    /// Flags beyond the raw value's capacity are ignored.
    func options<Options: OptionSet>(as: Options.Type) -> Options where Options.RawValue == UInt {
        let bitCount = min(bytes.count * 8 - paddingBits, UInt.bitWidth)
        var rawValue: UInt = 0
        for index in 0..<bitCount {
            if bytes[bytes.startIndex + index / 8] & (0x80 >> (index % 8)) != 0 {
                rawValue |= 1 << index
            }
        }
        return Options(rawValue: rawValue)
    }
}
