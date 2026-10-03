import Foundation
import SwiftASN1

/// Card command fields are implicitly tagged primitive values, serialized using definite lengths.
enum CardCommandPayload: DERSerializable {
    case algorithmReference(UInt8)
    case keyReference(UInt8)
    case digest(Data)

    var encoded: Data {
        var serializer = DER.Serializer()
        serialize(into: &serializer)
        return Data(serializer.serializedBytes)
    }

    func serialize(into serializer: inout DER.Serializer) {
        let tagNumber: UInt
        let bytes: Data
        switch self {
        case .algorithmReference(let reference):
            tagNumber = 0
            bytes = Data([reference])
        case .keyReference(let reference):
            tagNumber = 4
            bytes = Data([reference])
        case .digest(let digest):
            tagNumber = 16
            bytes = digest
        }
        serializer.appendPrimitiveNode(identifier: .init(tagWithNumber: tagNumber, tagClass: .contextSpecific)) {
            $0.append(contentsOf: bytes)
        }
    }
}
