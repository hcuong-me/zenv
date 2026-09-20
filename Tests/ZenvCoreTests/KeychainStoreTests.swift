import Foundation
import Testing
import ZenvCore

struct KeychainStoreTests {
    @Test func putGetListDeleteRoundTrip() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let path = dir.appendingPathComponent("zenv.keychain").path
        try KeychainStore.createFileKeychain(at: path, password: "test")
        let store = KeychainStore(service: "dev.hcuong.zenv.test", keychainPath: path)

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
        let store = KeychainStore(service: "dev.hcuong.zenv.test", keychainPath: path)
        #expect(try store.listKeys().isEmpty)
        #expect(try store.exportAll().isEmpty)
    }
}
