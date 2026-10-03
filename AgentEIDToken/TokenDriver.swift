import CryptoTokenKit
import OSLog

final class TokenDriver: TKSmartCardTokenDriver, TKSmartCardTokenDriverDelegate {
    override init() {
        super.init()
        delegate = self
    }

    func tokenDriver(
        _ driver: TKSmartCardTokenDriver, createTokenFor smartCard: TKSmartCard, aid: Data?
    ) throws -> TKSmartCardToken {
        do { return try Token(smartCard: smartCard, aid: aid, tokenDriver: self) }
        catch {
            Logger(subsystem: "fi.myyra.AgentEID", category: "token").error("Card discovery failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }
}
