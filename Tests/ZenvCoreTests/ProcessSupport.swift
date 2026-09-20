import Foundation
import ZenvCore

enum ZenvProcess {
    static func packageRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    static func findZenv() -> URL? {
        let root = packageRoot()
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

    static func isolatedEnv(home: URL, keychain: String) -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        env["HOME"] = home.path
        env["ZDOTDIR"] = home.path
        env["ZENV_HOME"] = home.path
        env["ZENV_SERVICE"] = "dev.hcuong.zenv.live"
        env["ZENV_KEYCHAIN"] = keychain
        env["SHELL"] = "/bin/zsh"
        let binDir = findZenv()?.deletingLastPathComponent().path ?? "/usr/bin"
        env["PATH"] = "\(binDir):/usr/bin:/bin:/usr/local/bin:/opt/homebrew/bin"
        return env
    }

    static func run(
        _ bin: URL,
        _ args: [String],
        env: [String: String],
        label: String = ""
    ) throws -> (stdout: String, stderr: String, status: Int32) {
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
        return (stdout, stderr, proc.terminationStatus)
    }

    static func p95Milliseconds(samples: [Double]) -> Double {
        var sorted = samples
        sorted.sort()
        return sorted[Int(Double(sorted.count) * 0.95) - 1]
    }
}
