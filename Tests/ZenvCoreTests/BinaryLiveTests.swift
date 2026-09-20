import Foundation
import Testing
import ZenvCore

struct BinaryLiveTests {
    @Test func storePutKeysEnvUpdateDeleteAndEmpty() throws {
        try withIsolatedCLI { bin, env, _ in
            let help = try ZenvProcess.run(bin, ["--help"], env: env)
            #expect(help.status == 0)
            #expect(help.stdout.contains("env"))
            #expect(help.stdout.contains("keys"))

            let empty = try ZenvProcess.run(bin, ["env"], env: env)
            #expect(empty.status == 0)
            #expect(empty.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            #expect(!empty.stderr.contains("secret"))

            _ = try requireOK(bin, ["put", "--key", "stripe_key", "--value", "sk_live_1"], env: env)
            let keys = try requireOK(bin, ["keys"], env: env)
            #expect(keys.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "STRIPE_KEY")

            let exported = try requireOK(bin, ["env"], env: env)
            #expect(exported.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == #"export STRIPE_KEY="sk_live_1""#)

            _ = try requireOK(bin, ["put", "--key", "STRIPE_KEY", "--value", "sk_live_2"], env: env)
            let updated = try requireOK(bin, ["env"], env: env)
            #expect(updated.stdout.contains("sk_live_2"))
            #expect(!updated.stdout.contains("sk_live_1"))

            let table = try requireOK(bin, ["ls"], env: env)
            #expect(table.stdout.contains("STRIPE_KEY"))
            #expect(table.stdout.contains("********"))
            #expect(!table.stdout.contains("sk_live_2"))

            let missing = try ZenvProcess.run(bin, ["rm", "NO_SUCH_KEY"], env: env)
            #expect(missing.status != 0)

            _ = try requireOK(bin, ["rm", "STRIPE_KEY"], env: env)
            let after = try requireOK(bin, ["keys"], env: env)
            #expect(after.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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

    @Test func doctorRequiresZshrcAndImportsZshenvOnce() throws {
        try withIsolatedCLI { bin, env, home in
            try FileManager.default.removeItem(at: home.appendingPathComponent(".zshrc"))
            let missing = try ZenvProcess.run(bin, ["doctor", "--yes"], env: env)
            #expect(missing.status != 0)
            #expect(!FileManager.default.fileExists(atPath: home.appendingPathComponent(".zshrc").path))

            try "".write(to: home.appendingPathComponent(".zshrc"), atomically: true, encoding: .utf8)
            try """
            # leave this comment
            export OLD_SECRET="from-file"
            export PATH="/usr/bin"
            """.write(
                to: home.appendingPathComponent(".zshenv"),
                atomically: true,
                encoding: .utf8
            )
            _ = try requireOK(bin, ["doctor", "--yes"], env: env)
            let zshrc = try String(contentsOf: home.appendingPathComponent(".zshrc"), encoding: .utf8)
            #expect(Hook.isInstalled(in: zshrc))
            #expect(FileManager.default.fileExists(atPath: home.appendingPathComponent(".zenv/backups/.zshrc.hook.backup").path))
            let keys = try requireOK(bin, ["keys"], env: env)
            #expect(keys.stdout.contains("OLD_SECRET"))
            #expect(!keys.stdout.split(separator: "\n").contains("PATH"))
            let zshenv = try String(contentsOf: home.appendingPathComponent(".zshenv"), encoding: .utf8)
            #expect(zshenv.contains("leave this comment"))
            #expect(zshenv.contains("PATH"))
            #expect(!zshenv.contains("OLD_SECRET"))

            let again = try requireOK(bin, ["doctor", "--yes"], env: env)
            #expect(again.status == 0)
            let twice = try String(contentsOf: home.appendingPathComponent(".zshrc"), encoding: .utf8)
            #expect(twice.components(separatedBy: Hook.startMarker).count - 1 == 1)
        }
    }

    @Test func migrateMovesSecretAndLeavesPath() throws {
        try withIsolatedCLI { bin, env, home in
            try """
            export PATH="/usr/bin"
            export API_KEY="migrated-secret"
            """.write(to: home.appendingPathComponent(".zshrc"), atomically: true, encoding: .utf8)
            let migrated = try requireOK(bin, ["migrate", "--yes"], env: env)
            #expect(migrated.stdout.contains("source ~/.zshrc"))
            let keys = try requireOK(bin, ["keys"], env: env)
            #expect(keys.stdout.contains("API_KEY"))
            #expect(!keys.stdout.contains("PATH"))
            let zshrc = try String(contentsOf: home.appendingPathComponent(".zshrc"), encoding: .utf8)
            #expect(zshrc.contains("PATH"))
            #expect(!zshrc.contains("API_KEY"))
            let reminder = try requireOK(bin, ["migrate", "--yes"], env: env)
            #expect(reminder.stdout.contains("source ~/.zshrc") || reminder.stdout.contains("No environment variables"))
        }
    }

    @Test func brokenZenvOnPathDoesNotKillShell() throws {
        try withIsolatedCLI { bin, env, home in
            try Hook.content.write(to: home.appendingPathComponent(".zshrc"), atomically: true, encoding: .utf8)
            let stubDir = home.appendingPathComponent("stub")
            try FileManager.default.createDirectory(at: stubDir, withIntermediateDirectories: true)
            let stub = stubDir.appendingPathComponent("zenv")
            try "#!/bin/sh\nexit 1\n".write(to: stub, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: stub.path)
            var broken = env
            broken["PATH"] = "\(stubDir.path):\(env["PATH"] ?? "/bin")"
            let survived = try ZenvProcess.run(
                URL(fileURLWithPath: "/bin/zsh"),
                ["-f", "-c", "source \"$HOME/.zshrc\"; echo survived; env >/dev/null"],
                env: broken
            )
            #expect(survived.status == 0)
            #expect(survived.stdout.contains("survived"))
        }
    }

    @Test func twentyKeysEnvAndLsStayUnderBudget() throws {
        try withIsolatedCLI { bin, env, _ in
            for i in 1...20 {
                _ = try requireOK(bin, ["put", "--key", "PERFKEY_\(i)", "--value", "v\(i)"], env: env)
            }
            var envSamples: [Double] = []
            var lsSamples: [Double] = []
            for _ in 0..<20 {
                let t0 = CFAbsoluteTimeGetCurrent()
                _ = try requireOK(bin, ["env"], env: env)
                envSamples.append((CFAbsoluteTimeGetCurrent() - t0) * 1000)
                let t1 = CFAbsoluteTimeGetCurrent()
                _ = try requireOK(bin, ["ls"], env: env)
                lsSamples.append((CFAbsoluteTimeGetCurrent() - t1) * 1000)
            }
            #expect(ZenvProcess.p95Milliseconds(samples: envSamples) < 200)
            #expect(ZenvProcess.p95Milliseconds(samples: lsSamples) < 150)
        }
    }

    private func withIsolatedCLI(_ body: (URL, [String: String], URL) throws -> Void) throws {
        guard let bin = ZenvProcess.findZenv() else {
            Issue.record("zenv binary missing under .build or dist")
            return
        }
        let home = FileManager.default.temporaryDirectory.appendingPathComponent("zenv-cli-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }
        let keychain = home.appendingPathComponent("zenv.keychain").path
        try KeychainStore.createFileKeychain(at: keychain, password: "test")
        try "".write(to: home.appendingPathComponent(".zshrc"), atomically: true, encoding: .utf8)
        try "".write(to: home.appendingPathComponent(".zshenv"), atomically: true, encoding: .utf8)
        let env = ZenvProcess.isolatedEnv(home: home, keychain: keychain)
        try body(bin, env, home)
    }

    private func requireOK(
        _ bin: URL,
        _ args: [String],
        env: [String: String]
    ) throws -> (stdout: String, stderr: String, status: Int32) {
        let result = try ZenvProcess.run(bin, args, env: env, label: args.first ?? "")
        if result.status != 0 {
            Issue.record("\(args.joined(separator: " ")) exited \(result.status) stderr=\(result.stderr.prefix(200))")
            throw KeychainStoreError.unexpectedStatus(result.status)
        }
        return result
    }
}
