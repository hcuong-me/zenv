import Foundation
import Testing
import ZenvCore

struct StoreLiveTests {
    @Test func putKeysEnvUpdateDeleteAndEmpty() throws {
        try withIsolatedCLI { bin, env, home in
            let help = try ZenvProcess.run(bin, ["--help"], env: env)
            #expect(help.status == 0)
            #expect(help.stdout.contains("env"))
            #expect(help.stdout.contains("keys"))

            let empty = try ZenvProcess.run(bin, ["env"], env: env)
            #expect(empty.status == 0)
            #expect(empty.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            _ = try requireOK(bin, ["put", "--key", "stripe_key", "--value", "sk_live_1"], env: env)
            let keys = try requireOK(bin, ["keys"], env: env)
            #expect(keys.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "STRIPE_KEY")

            let exported = try requireOK(bin, ["env"], env: env)
            #expect(exported.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == #"export STRIPE_KEY="sk_live_1""#)
            #expect(!exported.stderr.contains("sk_live"))

            _ = try requireOK(bin, ["put", "--key", "STRIPE_KEY", "--value", "sk_live_2"], env: env)
            let updated = try requireOK(bin, ["env"], env: env)
            #expect(updated.stdout.contains("sk_live_2"))
            #expect(!updated.stdout.contains("sk_live_1"))

            _ = try requireOK(bin, ["delete", "--key", "STRIPE_KEY"], env: env)
            let after = try requireOK(bin, ["keys"], env: env)
            #expect(after.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            let zshenv = home.appendingPathComponent(".zshenv")
            #expect((try Data(contentsOf: zshenv)).isEmpty)
        }
    }

    @Test func envEscapesEvalInZsh() throws {
        try withIsolatedCLI { bin, env, _ in
            let value = "a\\b\"c$d"
            _ = try requireOK(bin, ["put", "--key", "Q", "--value", value], env: env)
            let exported = try requireOK(bin, ["env"], env: env)
            var zshEnv = env
            zshEnv["ZENV_EVAL"] = exported.stdout
            zshEnv["EXPECT"] = value
            let check = try ZenvProcess.run(
                URL(fileURLWithPath: "/bin/zsh"),
                ["-f", "-c", "eval \"$ZENV_EVAL\"; if [ \"$Q\" = \"$EXPECT\" ]; then echo ok; else echo bad; fi"],
                env: zshEnv
            )
            #expect(check.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "ok")
        }
    }

    @Test func twentyKeysEnvP95Under200ms() throws {
        try withIsolatedCLI { bin, env, _ in
            for i in 1...20 {
                _ = try requireOK(bin, ["put", "--key", "PERFKEY_\(i)", "--value", "v\(i)"], env: env)
            }
            var samples: [Double] = []
            for _ in 0..<20 {
                let t0 = CFAbsoluteTimeGetCurrent()
                _ = try requireOK(bin, ["env"], env: env)
                samples.append((CFAbsoluteTimeGetCurrent() - t0) * 1000)
            }
            #expect(ZenvProcess.p95Milliseconds(samples: samples) < 200)
        }
    }

    private func withIsolatedCLI(_ body: (URL, [String: String], URL) throws -> Void) throws {
        guard let bin = ZenvProcess.findZenv() else {
            Issue.record("zenv binary missing under .build or dist")
            return
        }
        let home = FileManager.default.temporaryDirectory.appendingPathComponent("zenv-store-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }
        let keychain = home.appendingPathComponent("zenv.keychain").path
        try KeychainStore.createFileKeychain(at: keychain, password: "test")
        try "".write(to: home.appendingPathComponent(".zshenv"), atomically: true, encoding: .utf8)
        let env = ZenvProcess.isolatedEnv(home: home, keychain: keychain)
        try body(bin, env, home)
    }

    private func requireOK(
        _ bin: URL,
        _ args: [String],
        env: [String: String]
    ) throws -> (stdout: String, stderr: String, status: Int32) {
        let result = try ZenvProcess.run(bin, args, env: env)
        if result.status != 0 {
            Issue.record("\(args.joined(separator: " ")) exited \(result.status) stderr=\(result.stderr.prefix(200))")
            throw KeychainStoreError.unexpectedStatus(result.status)
        }
        return result
    }
}
