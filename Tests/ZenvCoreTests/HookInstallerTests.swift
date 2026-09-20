import Foundation
import Testing
import ZenvCore

struct HookInstallerTests {
    @Test func missingZshrcThrows() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }
        #expect(throws: HookInstallerError.zshrcMissing) {
            try HookInstaller.install(paths: ZenvPaths(home: home))
        }
    }

    @Test func writesHookAndBackup() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }
        let paths = ZenvPaths(home: home)
        try "export PATH=/usr/bin\n".write(to: paths.zshrc, atomically: true, encoding: .utf8)
        try HookInstaller.install(paths: paths)
        let text = try String(contentsOf: paths.zshrc, encoding: .utf8)
        #expect(Hook.isInstalled(in: text))
        #expect(FileManager.default.fileExists(atPath: paths.backupDir.appendingPathComponent(".zshrc.hook.backup").path))
        try HookInstaller.install(paths: paths)
        let again = try String(contentsOf: paths.zshrc, encoding: .utf8)
        #expect(again == text)
    }
}
