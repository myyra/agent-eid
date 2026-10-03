import Foundation
import Security

/// Mode and card identity are metadata on the shared PIN item. Saving or deleting
/// PIN1 changes the mode atomically, without a shared preferences container.
struct KeychainPINStore {
    private let service: String

    init(service: String = "fi.myyra.AgentEID.PIN1") { self.service = service }

    func settings() throws -> PINSettings {
        try readItem().map { try StoredPINSettings(attributes: $0).value } ?? PINSettings()
    }

    /// Match the original metadata so a concurrent save cannot rebind a newer PIN
    /// to this operation's card identity.
    func saveMode(_ mode: PINMode) throws {
        guard let attributes = try readItem() else {
            if mode == .native { return }
            throw PINProviderError.savedPINRequired
        }
        let stored = try StoredPINSettings(attributes: attributes)
        var settings = stored.value
        settings.mode = mode
        guard try update([kSecAttrGeneric: JSONEncoder().encode(settings)], matching: stored.encoded) else {
            throw PINProviderError.settingsChanged
        }
    }

    func save(_ pin: Data, cardID: String) throws {
        try SavedPIN.validate(pin)
        try SavedPIN.validate(cardID: cardID)
        let settings = PINSettings(mode: .keychain, savedCardID: cardID)
        let attributes: [CFString: Any] = [kSecValueData: pin, kSecAttrGeneric: try JSONEncoder().encode(settings)]
        if try !update(attributes) {
            var item = try query(adding: attributes)
            item[kSecAttrLabel] = String(localized: .keychainSavedPinLabel)
            item[kSecAttrAccessible] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            try check(SecItemAdd(item as CFDictionary, nil))
        }
    }

    /// Read PIN and metadata together; card binding is checked before any VERIFY.
    func pin(for cardID: String) throws -> Data {
        try SavedPIN.validate(cardID: cardID)
        guard let attributes = try readItem(includePIN: true) else {
            throw PINProviderError.noSavedPIN
        }
        let settings = try StoredPINSettings(attributes: attributes).value
        guard settings.mode == .keychain, settings.savedCardID == cardID else {
            throw PINProviderError.authenticationNotEnabledForCard
        }
        guard let pin = attributes[kSecValueData] as? Data else {
            throw PINProviderError.invalidStoredPIN
        }
        try SavedPIN.validate(pin)
        return pin
    }

    func forget() throws {
        let status = SecItemDelete(try query() as CFDictionary)
        if status != errSecItemNotFound { try check(status) }
    }

    private func query(adding attributes: [CFString: Any] = [:]) throws -> [CFString: Any] {
        guard let accessGroup = Bundle.main.object(forInfoDictionaryKey: "PINKeychainAccessGroup") as? String,
              !accessGroup.isEmpty, !accessGroup.contains("$(") else {
            throw PINProviderError.missingAccessGroup
        }
        return [kSecClass: kSecClassGenericPassword, kSecAttrService: service,
                kSecAttrAccount: "PIN1", kSecUseDataProtectionKeychain: true,
                kSecAttrAccessGroup: accessGroup, kSecAttrSynchronizable: false]
            .merging(attributes, uniquingKeysWith: { _, new in new })
    }

    private func readItem(includePIN: Bool = false) throws -> [CFString: Any]? {
        var attributes: [CFString: Any] = [kSecReturnAttributes: true, kSecMatchLimit: kSecMatchLimitOne]
        if includePIN { attributes[kSecReturnData] = true }
        var result: CFTypeRef?
        let status = SecItemCopyMatching(try query(adding: attributes) as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        try check(status)
        guard let item = result as? [CFString: Any] else {
            throw PINProviderError.invalidStoredPIN
        }
        return item
    }

    private func update(_ attributes: [CFString: Any], matching metadata: Data? = nil) throws -> Bool {
        let filter: [CFString: Any] = metadata.map { [kSecAttrGeneric: $0] } ?? [:]
        let status = SecItemUpdate(try query(adding: filter) as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound { return false }
        try check(status)
        return true
    }

    private func check(_ status: OSStatus) throws {
        guard status == errSecSuccess else {
            throw PINProviderError.keychain(status: status)
        }
    }
}

private struct StoredPINSettings {
    let value: PINSettings
    let encoded: Data

    init(attributes: [CFString: Any]) throws {
        guard let data = attributes[kSecAttrGeneric] as? Data,
              let settings = try? JSONDecoder().decode(PINSettings.self, from: data),
              let cardID = settings.savedCardID else {
            throw PINProviderError.invalidStoredSettings
        }
        try SavedPIN.validate(cardID: cardID)
        value = settings
        encoded = data
    }
}
