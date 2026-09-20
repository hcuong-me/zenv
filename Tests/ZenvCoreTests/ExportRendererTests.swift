import Testing
import ZenvCore

struct ExportRendererTests {
    @Test func escapesBackslashQuoteAndDollar() {
        let raw = "a\\b\"c$d"
        let escaped = ExportRenderer.escapeValue(raw)
        #expect(escaped == "a\\\\b\\\"c\\$d")
        #expect(ExportRenderer.unescapeValue(escaped) == raw)
    }

    @Test func exportLineWrapsDoubleQuotes() {
        #expect(ExportRenderer.exportLine(key: "API_KEY", value: "x") == "export API_KEY=\"x\"")
    }
}
