import Testing
import ZenvCore

private final class FakePrompt: Prompting, @unchecked Sendable {
    var lines: [String?]
    var secrets: [String?]
    var confirms: [Bool]

    init(lines: [String?] = [], secrets: [String?] = [], confirms: [Bool] = []) {
        self.lines = lines
        self.secrets = secrets
        self.confirms = confirms
    }

    func readLine(prompt: String) throws -> String? {
        lines.isEmpty ? nil : lines.removeFirst()
    }

    func readSecret(prompt: String) throws -> String? {
        secrets.isEmpty ? nil : secrets.removeFirst()
    }

    func confirm(title: String, description: String) throws -> Bool {
        confirms.isEmpty ? false : confirms.removeFirst()
    }
}

struct SetFormTests {
    @Test func cancelOnEmptyKeyReturnsNil() throws {
        let prompt = FakePrompt(lines: [""], secrets: ["secret"])
        #expect(try SetForm.run(prompt: prompt) == nil)
    }

    @Test func cancelOnNilValueReturnsNil() throws {
        let prompt = FakePrompt(lines: ["API_KEY"], secrets: [nil])
        #expect(try SetForm.run(prompt: prompt) == nil)
    }

    @Test func emptyValueThrows() throws {
        let prompt = FakePrompt(lines: ["api_key"], secrets: [""])
        #expect(throws: SetFormError.emptyValue) {
            try SetForm.run(prompt: prompt)
        }
    }

    @Test func uppercasesKey() throws {
        let prompt = FakePrompt(lines: ["stripe_key"], secrets: ["sk"])
        let form = try SetForm.run(prompt: prompt)
        #expect(form?.key == "STRIPE_KEY")
        #expect(form?.value == "sk")
    }
}
