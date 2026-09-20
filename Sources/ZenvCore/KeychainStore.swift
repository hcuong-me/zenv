import Darwin
import Foundation
import Security

public struct EnvVar: Equatable, Sendable {
    public var key: String
    public var value: String

    public init(key: String, value: String) {
        self.key = key
        self.value = value
    }
}

public enum KeychainStoreError: Error, Equatable, Sendable, CustomStringConvertible {
    case unexpectedStatus(OSStatus)
    case invalidItemData
    case reservedKey(String)

    public var description: String {
        switch self {
        case .unexpectedStatus(let status):
            return "keychain status \(status)"
        case .invalidItemData:
            return "invalid keychain item data"
        case .reservedKey(let key):
            return "key \(key) is reserved for zenv storage"
        }
    }
}

public struct KeychainStore: Sendable {
    public static let defaultService = "me.hcuong.zenv"
    /// Single generic-password account that holds the JSON map of all env keys.
    public static let bundleAccount = "__ZENV_BUNDLE__"

    public let service: String
    public let keychainPath: String?

    public init(service: String = KeychainStore.defaultService, keychainPath: String? = nil) {
        self.service = service
        self.keychainPath = keychainPath
    }

    public static func fromEnvironment() -> KeychainStore {
        KeychainStore(
            service: ProcessInfo.processInfo.environment["ZENV_SERVICE"] ?? defaultService,
            keychainPath: ProcessInfo.processInfo.environment["ZENV_KEYCHAIN"]
        )
    }

    public static func createFileKeychain(at path: String, password: String) throws {
        if FileManager.default.fileExists(atPath: path) {
            try FileManager.default.removeItem(atPath: path)
        }
        var keychain: SecKeychain?
        let status = password.withCString { ptr in
            SecKeychainCreate(path, UInt32(strlen(ptr)), ptr, false, nil, &keychain)
        }
        guard status == errSecSuccess else {
            throw KeychainStoreError.unexpectedStatus(status)
        }
    }

    public func put(key: String, value: String) throws {
        let account = try normalizedKey(key)
        var map = try loadMap()
        map[account] = value
        try saveMap(map)
    }

    public func get(key: String) throws -> String? {
        let account = try normalizedKey(key)
        return try loadMap()[account]
    }

    public func delete(key: String, missingOK: Bool = false) throws {
        let account = try normalizedKey(key)
        var map = try loadMap()
        guard map.removeValue(forKey: account) != nil else {
            if missingOK {
                return
            }
            throw KeychainStoreError.unexpectedStatus(errSecItemNotFound)
        }
        try saveMap(map)
    }

    public func listKeys() throws -> [String] {
        try loadMap().keys.sorted()
    }

    public func exportAll() throws -> [EnvVar] {
        let map = try loadMap()
        return try map.keys.sorted().map { key in
            guard let value = map[key] else {
                throw KeychainStoreError.invalidItemData
            }
            return EnvVar(key: key, value: value)
        }
    }

    // MARK: - Bundle I/O

    private func normalizedKey(_ key: String) throws -> String {
        let account = key.uppercased()
        if account == Self.bundleAccount {
            throw KeychainStoreError.reservedKey(account)
        }
        return account
    }

    private func loadMap() throws -> [String: String] {
        try adoptLegacyItemsIfNeeded()
        return try readBundleMap()
    }

    private func readBundleMap() throws -> [String: String] {
        guard let data = try copyBundleData() else {
            return [:]
        }
        return try decodeMap(data)
    }

    private func saveMap(_ map: [String: String]) throws {
        guard !map.isEmpty else {
            try deleteAccount(Self.bundleAccount, missingOK: true)
            return
        }
        let data = try encodeMap(map)
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: Self.bundleAccount,
            kSecUseAuthenticationUI as String: kSecUseAuthenticationUIFail,
        ]
        try attachKeychain(&query, adding: false)
        let attributes: [String: Any] = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }
        if updateStatus != errSecItemNotFound {
            throw KeychainStoreError.unexpectedStatus(updateStatus)
        }
        var addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: Self.bundleAccount,
            kSecAttrSynchronizable as String: kCFBooleanFalse as Any,
            kSecValueData as String: data,
        ]
        try attachKeychain(&addQuery, adding: true)
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw KeychainStoreError.unexpectedStatus(addStatus)
        }
    }

    private func copyBundleData() throws -> Data? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: Self.bundleAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseAuthenticationUI as String: kSecUseAuthenticationUIFail,
        ]
        try attachKeychain(&query, adding: false)
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw KeychainStoreError.unexpectedStatus(status)
        }
        guard let data = result as? Data else {
            throw KeychainStoreError.invalidItemData
        }
        return data
    }

    private func encodeMap(_ map: [String: String]) throws -> Data {
        do {
            return try JSONSerialization.data(withJSONObject: map, options: [.sortedKeys])
        } catch {
            throw KeychainStoreError.invalidItemData
        }
    }

    private func decodeMap(_ data: Data) throws -> [String: String] {
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw KeychainStoreError.invalidItemData
        }
        guard let map = object as? [String: String] else {
            throw KeychainStoreError.invalidItemData
        }
        return map
    }

    /// Merge leftover one-account-per-key items into the bundle, then delete them.
    private func adoptLegacyItemsIfNeeded() throws {
        let accounts = try copyAccounts()
        let legacy = accounts.filter { $0 != Self.bundleAccount }
        guard !legacy.isEmpty else {
            return
        }

        var map = try readBundleMap()
        for account in legacy {
            if map[account] != nil {
                try deleteAccount(account, missingOK: true)
                continue
            }
            guard let value = try copyLegacyValue(account: account) else {
                try deleteAccount(account, missingOK: true)
                continue
            }
            map[account] = value
            try deleteAccount(account, missingOK: true)
        }
        try saveMap(map)
    }

    private func copyLegacyValue(account: String) throws -> String? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseAuthenticationUI as String: kSecUseAuthenticationUIFail,
        ]
        try attachKeychain(&query, adding: false)
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw KeychainStoreError.unexpectedStatus(status)
        }
        guard let data = result as? Data, let value = String(data: data, encoding: .utf8) else {
            throw KeychainStoreError.invalidItemData
        }
        return value
    }

    private func copyAccounts() throws -> [String] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecMatchLimit as String: kSecMatchLimitAll,
            kSecReturnAttributes as String: true,
            kSecUseAuthenticationUI as String: kSecUseAuthenticationUIFail,
        ]
        try attachKeychain(&query, adding: false)
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return []
        }
        guard status == errSecSuccess else {
            throw KeychainStoreError.unexpectedStatus(status)
        }
        guard let items = result as? [[String: Any]] else {
            throw KeychainStoreError.invalidItemData
        }
        return try items.map { item in
            guard let account = item[kSecAttrAccount as String] as? String else {
                throw KeychainStoreError.invalidItemData
            }
            return account
        }
    }

    private func deleteAccount(_ account: String, missingOK: Bool) throws {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecUseAuthenticationUI as String: kSecUseAuthenticationUIFail,
        ]
        try attachKeychain(&query, adding: false)
        let status = SecItemDelete(query as CFDictionary)
        if status == errSecItemNotFound {
            if missingOK {
                return
            }
            throw KeychainStoreError.unexpectedStatus(status)
        }
        guard status == errSecSuccess else {
            throw KeychainStoreError.unexpectedStatus(status)
        }
    }

    private func attachKeychain(_ query: inout [String: Any], adding: Bool) throws {
        guard let path = keychainPath, !path.isEmpty else { return }
        var keychain: SecKeychain?
        let status = SecKeychainOpen(path, &keychain)
        guard status == errSecSuccess, let keychain else {
            throw KeychainStoreError.unexpectedStatus(status)
        }
        if adding {
            query[kSecUseKeychain as String] = keychain
        } else {
            query[kSecMatchSearchList as String] = [keychain]
        }
    }
}
