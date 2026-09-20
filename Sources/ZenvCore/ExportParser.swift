import Foundation

public enum ExportParser {
    public static func parseManagedLines(_ content: String) -> [EnvVar] {
        let linePattern = /^export ([A-Za-z_][A-Za-z0-9_]*)="(.*)"$/
        var vars: [EnvVar] = []
        for raw in content.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard let match = line.wholeMatch(of: linePattern) else { continue }
            let key = String(match.1)
            let value = ExportRenderer.unescapeValue(String(match.2))
            vars.append(EnvVar(key: key, value: value))
        }
        return vars
    }

    public static func stripManagedKeys(_ content: String, keys: Set<String>) -> String {
        let linePattern = /^export ([A-Za-z_][A-Za-z0-9_]*)="(.*)"$/
        let upper = Set(keys.map { $0.uppercased() })
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false)
        let kept = lines.filter { raw in
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard let match = line.wholeMatch(of: linePattern) else { return true }
            return !upper.contains(String(match.1).uppercased())
        }
        return kept.joined(separator: "\n")
    }
}
