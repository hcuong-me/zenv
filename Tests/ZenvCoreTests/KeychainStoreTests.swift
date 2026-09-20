import Foundation
import Security
import Testing
import ZenvCore

struct KeychainStoreTests {
    @Test func putGetListDeleteRoundTrip() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let path = dir.appendingPathComponent("zenv.keychain").path
        try KeychainStore.createFileKeychain(at: path, password: "test")
        let store = KeychainStore(service: "me.hcuong.zenv.test", keychainPath: path)

        try store.put(key: "stripe_key", value: "sk_live_1")
        #expect(try store.get(key: "stripe_key") == "sk_live_1")
        #expect(try store.listKeys() == ["STRIPE_KEY"])

        try store.put(key: "STRIPE_KEY", value: "sk_live_2")
        #expect(try store.exportAll() == [EnvVar(key: "STRIPE_KEY", value: "sk_live_2")])

        try store.delete(key: "stripe_key")
        #expect(try store.listKeys().isEmpty)
    }

    @Test func emptyStoreListsNothing() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let path = dir.appendingPathComponent("zenv.keychain").path
        try KeychainStore.createFileKeychain(at: path, password: "test")
        let store = KeychainStore(service: "me.hcuong.zenv.test", keychainPath: path)
        #expect(try store.listKeys().isEmpty)
        #expect(try store.exportAll().isEmpty)
    }

    @Test func multipleKeysShareOneBundleAccount() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let path = dir.appendingPathComponent("zenv.keychain").path
        try KeychainStore.createFileKeychain(at: path, password: "test")
        let service = "me.hcuong.zenv.test.bundle"
        let store = KeychainStore(service: service, keychainPath: path)

        try store.put(key: "A", value: "1")
        try store.put(key: "B", value: "2")
        #expect(try store.exportAll() == [
            EnvVar(key: "A", value: "1"),
            EnvVar(key: "B", value: "2"),
        ])
        #expect(try keychainAccounts(service: service, path: path) == [KeychainStore.bundleAccount])
    }

    @Test func adoptsLegacyPerKeyItemsIntoBundle() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let path = dir.appendingPathComponent("zenv.keychain").path
        try KeychainStore.createFileKeychain(at: path, password: "test")
        let service = "me.hcuong.zenv.test.legacy"
        try addLegacyItem(service: service, account: "OLD_KEY", value: "legacy", path: path)
        try addLegacyItem(service: service, account: "OTHER", value: "x", path: path)

        let store = KeychainStore(service: service, keychainPath: path)
        #expect(try store.get(key: "OLD_KEY") == "legacy")
        #expect(try store.listKeys() == ["OLD_KEY", "OTHER"])
        #expect(try keychainAccounts(service: service, path: path) == [KeychainStore.bundleAccount])
    }

    @Test func rejectsReservedBundleKey() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let path = dir.appendingPathComponent("zenv.keychain").path
        try KeychainStore.createFileKeychain(at: path, password: "test")
        let store = KeychainStore(service: "me.hcuong.zenv.test.reserved", keychainPath: path)
        #expect(throws: KeychainStoreError.reservedKey(KeychainStore.bundleAccount)) {
            try store.put(key: KeychainStore.bundleAccount, value: "nope")
        }
    }
}

private func openKeychain(_ path: String) throws -> SecKeychain {
    var keychain: SecKeychain?
    let status = SecKeychainOpen(path, &keychain)
    guard status == errSecSuccess, let keychain else {
        throw KeychainStoreError.unexpectedStatus(status)
    }
    return keychain
}

private func addLegacyItem(service: String, account: String, value: String, path: String) throws {
    let keychain = try openKeychain(path)
    guard let data = value.data(using: .utf8) else {
        throw KeychainStoreError.invalidItemData
    }
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: service,
        kSecAttrAccount as String: account,
        kSecAttrSynchronizable as String: kCFBooleanFalse as Any,
        kSecValueData as String: data,
        kSecUseKeychain as String: keychain,
    ]
    let status = SecItemAdd(query as CFDictionary, nil)
    guard status == errSecSuccess else {
        throw KeychainStoreError.unexpectedStatus(status)
    }
}

private func keychainAccounts(service: String, path: String) throws -> [String] {
    let keychain = try openKeychain(path)
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: service,
        kSecMatchLimit as String: kSecMatchLimitAll,
        kSecReturnAttributes as String: true,
        kSecMatchSearchList as String: [keychain],
    ]
    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    if status == errSecItemNotFound {
        return []
    }
    guard status == errSecSuccess, let items = result as? [[String: Any]] else {
        throw KeychainStoreError.unexpectedStatus(status)
    }
    return items.compactMap { $0[kSecAttrAccount as String] as? String }.sorted()
}
