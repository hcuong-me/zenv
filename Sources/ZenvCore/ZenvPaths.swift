import Foundation

public struct ZenvPaths: Sendable {
    public var home: URL

    public init(home: URL) {
        self.home = home
    }

    public var zshrc: URL {
        home.appendingPathComponent(".zshrc")
    }

    public var backupDir: URL {
        home.appendingPathComponent(".zenv").appendingPathComponent("backups")
    }

    public static func live() -> ZenvPaths {
        if let home = ProcessInfo.processInfo.environment["ZENV_HOME"], !home.isEmpty {
            return ZenvPaths(home: URL(fileURLWithPath: home, isDirectory: true))
        }
        return ZenvPaths(home: FileManager.default.homeDirectoryForCurrentUser)
    }
}

public enum ShellCheck {
    public static func isZsh(shell: String = ProcessInfo.processInfo.environment["SHELL"] ?? "") -> Bool {
        shell.contains("zsh")
    }
}
