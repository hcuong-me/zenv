import Testing
import ZenvCore

struct MigrateTests {
    @Test func skipsPathFamily() {
        #expect(Migrate.shouldExclude(key: "PATH"))
        #expect(Migrate.shouldExclude(key: "GOPATH"))
        #expect(Migrate.shouldExclude(key: "PATH_HELPER"))
        #expect(!Migrate.shouldExclude(key: "API_KEY"))
    }

    @Test func parseSkipsHookBlockAndPath() {
        let content = """
        export PATH="/usr/bin"
        export API_KEY="secret"
        \(Hook.startMarker)
        export HOOK_ONLY="nope"
        \(Hook.endMarker)
        export DB_PASSWORD='hunter2'
        """
        let vars = Migrate.parseExports(from: content)
        #expect(vars.map(\.key).sorted() == ["API_KEY", "DB_PASSWORD"])
        #expect(vars.first { $0.key == "API_KEY" }?.value == "secret")
        #expect(vars.first { $0.key == "DB_PASSWORD" }?.value == "hunter2")
    }

    @Test func removeExportsDropsSelectedKeys() {
        let content = "export API_KEY=a\nexport KEEP=b\n"
        let next = Migrate.removeExports(from: content, keys: ["API_KEY"])
        #expect(next.contains("KEEP"))
        #expect(!next.contains("API_KEY"))
    }
}
