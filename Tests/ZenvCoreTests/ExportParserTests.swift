import Foundation
import Testing
import ZenvCore

struct ExportParserTests {
    @Test func parseAndStripManagedLines() {
        let content = """
        # keep me
        export API_KEY="ab\\"c"
        export PATH="/usr/bin"
        """
        let vars = ExportParser.parseManagedLines(content)
        #expect(vars.map(\.key) == ["API_KEY", "PATH"])
        #expect(vars[0].value == "ab\"c")
        let imported = vars.filter { !Migrate.shouldExclude(key: $0.key) }
        #expect(imported.map(\.key) == ["API_KEY"])
        let stripped = ExportParser.stripManagedKeys(content, keys: ["API_KEY"])
        #expect(stripped.contains("PATH"))
        #expect(!stripped.contains("API_KEY"))
        #expect(stripped.contains("# keep me"))
    }
}

struct ListTableTests {
    @Test func emptyAndMasked() {
        #expect(ListTable.render(keys: []) == "No environment variables set.")
        let table = ListTable.render(keys: ["API_KEY"])
        #expect(table.contains("API_KEY"))
        #expect(table.contains("********"))
        #expect(table.contains("Keychain"))
    }
}
