import Testing
import ZenvCore

struct HookTests {
    @Test func contentLoadsFromZenvEnvNotZshenv() {
        #expect(Hook.content.contains("zenv env"))
        #expect(Hook.content.contains("_zenv_masker"))
        #expect(Hook.content.contains("printenv()"))
        #expect(!Hook.content.contains(".zshenv"))
        #expect(Hook.isInstalled(in: Hook.content))
    }

    @Test func installIsIdempotent() {
        let once = Hook.install(into: "export PATH=/usr/bin\n")
        let twice = Hook.install(into: once)
        #expect(once == twice)
        #expect(once.contains(Hook.startMarker))
    }
}
