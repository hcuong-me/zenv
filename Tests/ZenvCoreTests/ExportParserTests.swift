import Foundation
import Testing
import ZenvCore

struct ListTableTests {
    @Test func emptyAndMasked() {
        #expect(ListTable.render(keys: []) == "No environment variables set.")
        let table = ListTable.render(keys: ["API_KEY", "ANTIGRAVITY_API_KEY"])
        #expect(table.contains("API_KEY"))
        #expect(table.contains("********"))
        #expect(table.contains("Keychain"))
        let box = table.split(separator: "\n").map(String.init).filter {
            $0.hasPrefix("┌") || $0.hasPrefix("│") || $0.hasPrefix("├") || $0.hasPrefix("└")
        }
        let width = box[0].count
        #expect(box.allSatisfy { $0.count == width })
        #expect(box.contains { $0.contains("VALUE") && $0.contains("KEY") })
    }
}
