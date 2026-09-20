import Foundation
import Testing
import ZenvCore

struct VersionTests {
    @Test func shortVMatchesVersionSubcommand() throws {
        guard let bin = ZenvProcess.findZenv() else {
            Issue.record("zenv binary missing under .build or dist")
            return
        }
        let home = FileManager.default.temporaryDirectory.appendingPathComponent("zenv-ver-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }
        let keychain = home.appendingPathComponent("zenv.keychain").path
        try KeychainStore.createFileKeychain(at: keychain, password: "test")
        let env = ZenvProcess.isolatedEnv(home: home, keychain: keychain)

        let short = try ZenvProcess.run(bin, ["-v"], env: env)
        let sub = try ZenvProcess.run(bin, ["version"], env: env)
        #expect(short.status == 0)
        #expect(sub.status == 0)
        let shortOut = short.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        let subOut = sub.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(shortOut == subOut)
        #expect(shortOut.hasPrefix("zenv version "))
    }
}
