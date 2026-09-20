import Foundation

public enum Migrate {
    public static func shouldExclude(key: String) -> Bool {
        let upper = key.uppercased()
        if upper == "PATH" { return true }
        if upper.hasSuffix("PATH") { return true }
        if upper.hasPrefix("PATH_") { return true }
        return false
    }

    public static func parseExports(from content: String) -> [EnvVar] {
        let exportPattern = /^\s*export\s+([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$/
        var vars: [EnvVar] = []
        var inHook = false
        for raw in content.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(raw)
            if line.contains(Hook.startMarker) {
                inHook = true
                continue
            }
            if line.contains(Hook.endMarker) {
                inHook = false
                continue
            }
            if inHook { continue }
            guard let match = line.wholeMatch(of: exportPattern) else { continue }
            let key = String(match.1)
            if shouldExclude(key: key) { continue }
            vars.append(EnvVar(key: key.uppercased(), value: extractValue(String(match.2))))
        }
        return vars
    }

    public static func removeExports(from content: String, keys: [String]) -> String {
        let remove = Set(keys.map { $0.uppercased() })
        let exportPattern = /^\s*export\s+([A-Za-z_][A-Za-z0-9_]*)\s*=.*$/
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false)
        let kept = lines.filter { raw in
            let line = String(raw)
            guard let match = line.wholeMatch(of: exportPattern) else { return true }
            return !remove.contains(String(match.1).uppercased())
        }
        return kept.joined(separator: "\n")
    }

    public struct Result: Equatable, Sendable {
        public var migrated: [String]
        public var skipped: [String]
        public var failed: [String]
        public var backupPath: String

        public init(migrated: [String] = [], skipped: [String] = [], failed: [String] = [], backupPath: String = "") {
            self.migrated = migrated
            self.skipped = skipped
            self.failed = failed
            self.backupPath = backupPath
        }
    }

    public static func apply(
        vars: [EnvVar],
        zshrcURL: URL,
        backupDir: URL,
        store: KeychainStore,
        fileManager: FileManager = .default
    ) throws -> Result {
        let existing = Set(try store.listKeys())
        var result = Result()
        for item in vars {
            let key = item.key.uppercased()
            if existing.contains(key) {
                result.skipped.append(key)
                continue
            }
            do {
                try store.put(key: key, value: item.value)
                result.migrated.append(key)
            } catch {
                result.failed.append(key)
            }
        }
        try fileManager.createDirectory(at: backupDir, withIntermediateDirectories: true)
        let original = try String(contentsOf: zshrcURL, encoding: .utf8)
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "")
        let backup = backupDir.appendingPathComponent(".zshrc.migrate.backup.\(stamp)")
        try original.write(to: backup, atomically: true, encoding: .utf8)
        result.backupPath = backup.path
        let next = removeExports(from: original, keys: result.migrated)
        try next.write(to: zshrcURL, atomically: true, encoding: .utf8)
        return result
    }

    private static func extractValue(_ raw: String) -> String {
        var value = raw.trimmingCharacters(in: .whitespaces)
        if let idx = value.range(of: " #") {
            value = String(value[..<idx.lowerBound])
        }
        if value.count >= 2 {
            if value.hasPrefix("\""), value.hasSuffix("\"") {
                return ExportRenderer.unescapeValue(String(value.dropFirst().dropLast()))
            }
            if value.hasPrefix("'"), value.hasSuffix("'") {
                return String(value.dropFirst().dropLast())
            }
        }
        return value
    }
}
