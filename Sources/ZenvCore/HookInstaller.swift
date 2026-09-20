import Foundation

public enum HookInstallerError: Error, Equatable, Sendable {
    case zshrcMissing
}

public enum HookInstaller {
    public static func install(paths: ZenvPaths, fileManager: FileManager = .default) throws {
        let zshrc = paths.zshrc.path
        guard fileManager.fileExists(atPath: zshrc) else {
            throw HookInstallerError.zshrcMissing
        }
        let original = try String(contentsOfFile: zshrc, encoding: .utf8)
        if Hook.isInstalled(in: original) {
            return
        }
        try fileManager.createDirectory(at: paths.backupDir, withIntermediateDirectories: true)
        let backup = paths.backupDir.appendingPathComponent(".zshrc.hook.backup")
        try original.write(to: backup, atomically: true, encoding: .utf8)
        let next = Hook.install(into: original)
        try next.write(to: paths.zshrc, atomically: true, encoding: .utf8)
    }
}
