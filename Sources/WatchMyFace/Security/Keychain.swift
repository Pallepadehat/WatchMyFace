import Foundation
import Security

nonisolated enum KeychainError: LocalizedError {
    case unexpectedStatus(OSStatus)

    var errorDescription: String? {
        switch self {
        case .unexpectedStatus(let status):
            let message = SecCopyErrorMessageString(status, nil) as String? ?? "error \(status)"
            return "The Keychain said: \(message)"
        }
    }
}

/// Generic password items in your login keychain, under the service `com.pallepadehat.WatchMyFace`.
///
/// The Keychain only hands an item to the app that made it (signed the same way); anything else asking gets a
/// prompt for your password first. That's also why an ad hoc build, which is signed differently every time, finds
/// its items again only after you allow it.
nonisolated enum Keychain {
    private static let service = "com.pallepadehat.WatchMyFace"

    static func read(_ account: String) throws -> Data? {
        var result: CFTypeRef?
        let status = SecItemCopyMatching(
            [
                kSecClass: kSecClassGenericPassword,
                kSecAttrService: service,
                kSecAttrAccount: account,
                kSecReturnData: true,
                kSecMatchLimit: kSecMatchLimitOne,
            ] as CFDictionary, &result)
        switch status {
        case errSecSuccess: return result as? Data
        case errSecItemNotFound: return nil
        default: throw KeychainError.unexpectedStatus(status)
        }
    }

    static func contains(_ account: String) -> Bool {
        let status = SecItemCopyMatching(
            [
                kSecClass: kSecClassGenericPassword,
                kSecAttrService: service,
                kSecAttrAccount: account,
                kSecMatchLimit: kSecMatchLimitOne,
            ] as CFDictionary, nil)
        return status == errSecSuccess || status == errSecInteractionNotAllowed
    }

    static func save(_ data: Data, as account: String, label: String) throws {
        let query: [CFString: Any] = [kSecClass: kSecClassGenericPassword, kSecAttrService: service, kSecAttrAccount: account]
        let update = SecItemUpdate(query as CFDictionary, [kSecValueData: data] as CFDictionary)
        if update == errSecSuccess { return }
        guard update == errSecItemNotFound else { throw KeychainError.unexpectedStatus(update) }

        var item = query
        item[kSecValueData] = data
        item[kSecAttrLabel] = label
        // Readable only while you're logged in, and never synced to other Macs.
        item[kSecAttrAccessible] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.unexpectedStatus(status) }
    }

    static func delete(_ account: String) throws {
        let status = SecItemDelete(
            [kSecClass: kSecClassGenericPassword, kSecAttrService: service, kSecAttrAccount: account] as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainError.unexpectedStatus(status) }
    }
}
