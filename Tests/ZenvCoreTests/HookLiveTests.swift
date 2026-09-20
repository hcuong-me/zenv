import Foundation
import Testing
import ZenvCore

struct HookLiveTests {
    @Test func zshrcLoadsKeychainWithoutWritingZshenv() throws {
        let root = packageRoot()
        guard let bin = findZenv(root: root) else {
            Issue.record("zenv binary missing under .build or dist")
            return
        }

        let home = FileManager.default.temporaryDirectory.appendingPathComponent("zenv-live-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }

        let keychain = home.appendingPathComponent("zenv.keychain").path
        try KeychainStore.createFileKeychain(at: keychain, password: "test")
        try "".write(to: home.appendingPathComponent(".zshrc"), atomically: true, encoding: .utf8)
        let zshenv = home.appendingPathComponent(".zshenv")
        try "".write(to: zshenv, atomically: true, encoding: .utf8)
        let zshenvBefore = try Data(contentsOf: zshenv)

        var env = ProcessInfo.processInfo.environment
        env["HOME"] = home.path
        env["ZDOTDIR"] = home.path
        env["ZENV_HOME"] = home.path
        env["ZENV_SERVICE"] = "dev.hcuong.zenv.live"
        env["ZENV_KEYCHAIN"] = keychain
        env["SHELL"] = "/bin/zsh"
        env["PATH"] = "\(bin.deletingLastPathComponent().path):/usr/bin:/bin:/usr/local/bin:/opt/homebrew/bin"

        _ = try run(bin, ["put", "--key", "LIVECHECK_KEY", "--value", "livecheck-secret"], env: env)
        _ = try run(bin, ["doctor", "--yes"], env: env)
        let keys = try run(bin, ["keys"], env: env)
        #expect(keys.stdout.split(separator: "\n").contains("LIVECHECK_KEY"))

        let zshrc = try String(contentsOf: home.appendingPathComponent(".zshrc"), encoding: .utf8)
        #expect(Hook.isInstalled(in: zshrc))
        #expect(!zshrc.contains("livecheck-secret"))
        #expect(try Data(contentsOf: zshenv) == zshenvBefore)

        let envOut = try run(
            URL(fileURLWithPath: "/bin/zsh"),
            ["-f", "-c", "source \"$HOME/.zshrc\"; env"],
            env: env,
            label: "env"
        )
        #expect(envOut.stdout.contains("LIVECHECK_KEY=********"))

        let masked = try run(
            URL(fileURLWithPath: "/bin/zsh"),
            ["-f", "-c", "source \"$HOME/.zshrc\"; printenv LIVECHECK_KEY"],
            env: env,
            label: "printenv"
        )
        #expect(masked.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "********")

        let child = try run(
            URL(fileURLWithPath: "/bin/zsh"),
            ["-f", "-c", "source \"$HOME/.zshrc\"; if [ \"$LIVECHECK_KEY\" = \"livecheck-secret\" ]; then echo ok; else echo bad; fi"],
            env: env,
            label: "child"
        )
        #expect(child.stdout.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix("ok"))

        let empty = try run(
            URL(fileURLWithPath: "/bin/zsh"),
            ["-f", "-c", "printenv LIVECHECK_KEY || true"],
            env: env,
            label: "noload"
        )
        #expect(empty.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        #expect(try Data(contentsOf: zshenv) == zshenvBefore)

        var samples: [Double] = []
        samples.reserveCapacity(20)
        for _ in 0..<20 {
            let t0 = CFAbsoluteTimeGetCurrent()
            _ = try run(bin, ["env"], env: env, label: "perf-env")
            samples.append((CFAbsoluteTimeGetCurrent() - t0) * 1000)
        }
        samples.sort()
        let p95 = samples[Int(Double(samples.count) * 0.95) - 1]
        #expect(p95 < 200)
    }

    private func packageRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func findZenv(root: URL) -> URL? {
        let fm = FileManager.default
        let direct = [
            root.appendingPathComponent(".build/debug/zenv"),
            root.appendingPathComponent(".build/release/zenv"),
            root.appendingPathComponent("dist/zenv"),
        ]
        if let hit = direct.first(where: { fm.isExecutableFile(atPath: $0.path) }) {
            return hit
        }
        let build = root.appendingPathComponent(".build")
        guard let enumerator = fm.enumerator(at: build, includingPropertiesForKeys: nil) else {
            return nil
        }
        while let item = enumerator.nextObject() as? URL {
            if item.lastPathComponent == "zenv", fm.isExecutableFile(atPath: item.path), !item.path.contains("dSYM") {
                return item
            }
        }
        return nil
    }

    private func run(_ bin: URL, _ args: [String], env: [String: String], label: String = "") throws -> (stdout: String, status: Int32) {
        let proc = Process()
        proc.executableURL = bin
        proc.arguments = args
        proc.environment = env
        let out = Pipe()
        let err = Pipe()
        proc.standardOutput = out
        proc.standardError = err
        try proc.run()
        proc.waitUntilExit()
        let stdout = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        if proc.terminationStatus != 0 {
            Issue.record("\(label.isEmpty ? bin.lastPathComponent : label) \(args.first ?? "") exited \(proc.terminationStatus) stderr=\(stderr.prefix(200))")
            throw KeychainStoreError.unexpectedStatus(proc.terminationStatus)
        }
        return (stdout, proc.terminationStatus)
    }
}
