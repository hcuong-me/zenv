import Foundation

public enum ZshenvImport {
    public static func importAndStrip(
        zshenvURL: URL,
        store: KeychainStore,
        fileManager: FileManager = .default
    ) throws -> [String] {
        guard fileManager.fileExists(atPath: zshenvURL.path) else {
            return []
        }
        let content = try String(contentsOf: zshenvURL, encoding: .utf8)
        let vars = ExportParser.parseManagedLines(content).filter { !Migrate.shouldExclude(key: $0.key) }
        guard !vars.isEmpty else { return [] }
        var imported: [String] = []
        for item in vars {
            try store.put(key: item.key, value: item.value)
            imported.append(item.key.uppercased())
        }
        let next = ExportParser.stripManagedKeys(content, keys: Set(imported))
        try next.write(to: zshenvURL, atomically: true, encoding: .utf8)
        return imported
    }
}
