public enum ExportRenderer: Sendable {
    public static func escapeValue(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "$", with: "\\$")
    }

    public static func unescapeValue(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\$", with: "$")
            .replacingOccurrences(of: "\\\"", with: "\"")
            .replacingOccurrences(of: "\\\\", with: "\\")
    }

    public static func exportLine(key: String, value: String) -> String {
        "export \(key)=\"\(escapeValue(value))\""
    }
}
