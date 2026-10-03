import CryptoTokenKit
import Foundation

/// Response data excludes SW1/SW2; a returned card status may indicate failure.
struct CardResponse: Sendable {
    let status: CardStatus
    let response: Data

    init(sw: UInt16, response: Data) {
        status = CardStatus(rawValue: sw)
        self.response = response
    }
}

/// The caller owns the active exclusive session. Card failures are returned as statuses;
/// errors without a card status are thrown. Implementations must not retry PIN verification.
protocol CardTransport {
    func send(ins: UInt8, p1: UInt8, p2: UInt8, data: Data?, le: Int?) throws -> CardResponse
}

struct SmartCardTransport: CardTransport {
    let card: TKSmartCard

    /// The refined API retains SW1SW2 on errors; VERIFY is never automatically retried.
    /// CryptoTokenKit handles ISO 7816 continuation and protocol-specific APDU framing.
    func send(ins: UInt8, p1: UInt8, p2: UInt8, data: Data?, le: Int?) throws -> CardResponse {
        var status: UInt16 = 0
        do {
            let response = try card.__sendIns(
                ins, p1: p1, p2: p2, data: data, le: le.map { NSNumber(value: $0) }, sw: &status
            )
            return CardResponse(sw: status, response: response)
        } catch {
            if status != 0 { return CardResponse(sw: status, response: Data()) }
            throw error
        }
    }
}
