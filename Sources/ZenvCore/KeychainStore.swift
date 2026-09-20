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

public enum KeychainStoreError: Error, Equatable, Sendable {
    case unexpectedStatus(OSStatus)
    case invalidItemData
}

public struct KeychainStore: Sendable {
    public static let defaultService = "me.hcuong.zenv"

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
        let account = key.uppercased()
        try delete(key: account, missingOK: true)
        guard let data = value.data(using: .utf8) else {
            throw KeychainStoreError.invalidItemData
        }
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: kCFBooleanFalse as Any,
            kSecValueData as String: data,
        ]
        try attachKeychain(&query, adding: true)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainStoreError.unexpectedStatus(status)
        }
    }

    public func get(key: String) throws -> String? {
        let account = key.uppercased()
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

    public func delete(key: String, missingOK: Bool = false) throws {
        let account = key.uppercased()
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

    public func listKeys() throws -> [String] {
        try copyAccounts().sorted()
    }

    public func exportAll() throws -> [EnvVar] {
        try listKeys().map { key in
            guard let value = try get(key: key) else {
                throw KeychainStoreError.invalidItemData
            }
            return EnvVar(key: key, value: value)
        }
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
