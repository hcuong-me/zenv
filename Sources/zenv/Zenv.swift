import ArgumentParser
import Foundation
import Security
import ZenvCore

@main
struct Zenv: ParsableCommand {
    static let version = "1.0.0"

    static let configuration = CommandConfiguration(
        commandName: "zenv",
        abstract: "Secure shell environment manager for macOS Zsh",
        version: version,
        subcommands: [Doctor.self, Set.self, Ls.self, Rm.self, Migrate.self, Env.self, Keys.self, Version.self, Put.self, Delete.self],
        defaultSubcommand: nil
    )

    @Flag(name: .customShort("v"), help: "Show the version.")
    var showVersion = false

    func run() throws {
        if showVersion {
            print(Self.versionLine)
            return
        }
        throw CleanExit.helpRequest(self)
    }

    static var versionLine: String {
        "zenv version \(version)"
    }
}

enum LiveStore {
    static func open() throws -> KeychainStore {
        KeychainStore.fromEnvironment()
    }
}

struct Version: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Show version"
    )

    func run() {
        print(Zenv.versionLine)
    }
}

struct Env: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Print export lines for all stored secrets"
    )

    func run() throws {
        let vars = try LiveStore.open().exportAll()
        for item in vars {
            print(ExportRenderer.exportLine(key: item.key, value: item.value))
        }
    }
}

struct Keys: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Print stored key names"
    )

    func run() throws {
        for key in try LiveStore.open().listKeys() {
            print(key)
        }
    }
}

struct Put: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Store a secret (test helper)",
        shouldDisplay: false
    )

    @Option var key: String
    @Option var value: String

    func run() throws {
        try LiveStore.open().put(key: key, value: value)
    }
}

struct Delete: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "kc-delete",
        abstract: "Delete a stored secret (test helper)",
        shouldDisplay: false
    )

    @Option var key: String

    func run() throws {
        try LiveStore.open().delete(key: key)
    }
}

struct Doctor: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Check and configure the Zsh hook"
    )

    @Flag(name: .long, help: "Install the hook without a prompt")
    var yes = false

    func run() throws {
        if !ShellCheck.isZsh() {
            print("Error: Only Zsh is supported.")
            print("   Current shell: \(ProcessInfo.processInfo.environment["SHELL"] ?? "")")
            throw ExitCode.failure
        }
        print("Using Zsh shell")

        let paths = ZenvPaths.live()
        let fm = FileManager.default
        if !fm.fileExists(atPath: paths.zshrc.path) {
            print("Error: ~/.zshrc not found")
            print("   Please create it first: touch ~/.zshrc")
            throw ExitCode.failure
        }
        print("~/.zshrc exists")

        let zshrc = try String(contentsOf: paths.zshrc, encoding: .utf8)
        if Hook.isInstalled(in: zshrc) {
            print("zenv shell hook is installed")
        } else {
            print("zenv shell hook is not installed")
            let ok: Bool
            if yes {
                ok = true
            } else {
                ok = try TerminalPrompt().confirm(
                    title: "Install Shell Hook?",
                    description: "This will add a script to ~/.zshrc that loads Keychain secrets and masks env/printenv."
                )
            }
            if ok {
                try HookInstaller.install(paths: paths)
                print("Shell hook installed successfully")
                print("Please restart your terminal or run: source ~/.zshrc")
            } else {
                print("Installation cancelled.")
            }
        }

        print("Doctor check complete!")
    }
}

struct Set: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Add or update an environment variable"
    )

    func run() throws {
        if !ShellCheck.isZsh() {
            print("Warning: zenv is designed for Zsh. Some features may not work correctly.")
        }
        let store = try LiveStore.open()
        do {
            guard let form = try SetForm.run(prompt: TerminalPrompt()) else {
                return
            }
            let existing = Swift.Set(try store.listKeys())
            let wasUpdate = existing.contains(form.key)
            try store.put(key: form.key, value: form.value)
            if wasUpdate {
                print("Updated \(form.key)")
            } else {
                print("Added \(form.key)")
            }
            print("")
            print("Run 'source ~/.zshrc' or restart your terminal to use this variable.")
        } catch SetFormError.emptyValue {
            print("Error: value cannot be empty")
            throw ExitCode.failure
        }
    }
}

struct Ls: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "List managed environment variables",
        aliases: ["list"]
    )

    func run() throws {
        let keys = try LiveStore.open().listKeys()
        print(ListTable.render(keys: keys))
    }
}

struct Rm: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Remove an environment variable",
        aliases: ["remove", "delete"]
    )

    @Argument var key: String

    func run() throws {
        do {
            try LiveStore.open().delete(key: key)
        } catch KeychainStoreError.unexpectedStatus(let status) where status == errSecItemNotFound {
            print("Error: environment variable \(key.uppercased()) not found")
            throw ExitCode.failure
        }
        unsetenv(key.uppercased())
        print("Removed \(key.uppercased())")
    }
}

struct Migrate: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Migrate export lines from ~/.zshrc into Keychain"
    )

    @Flag(name: .long, help: "Migrate every eligible export without a prompt")
    var yes = false

    func run() throws {
        let paths = ZenvPaths.live()
        let fm = FileManager.default
        guard fm.fileExists(atPath: paths.zshrc.path) else {
            print("Error: ~/.zshrc not found.")
            throw ExitCode.failure
        }
        let content = try String(contentsOf: paths.zshrc, encoding: .utf8)
        let vars = ZenvCore.Migrate.parseExports(from: content)
        if vars.isEmpty {
            print("No environment variables found in ~/.zshrc.")
            return
        }
        let selected: [EnvVar]
        if yes {
            selected = vars
        } else {
            print("Found \(vars.count) variable(s):")
            for item in vars {
                print("  \(item.key)")
            }
            let ok = try TerminalPrompt().confirm(
                title: "Migrate these variables?",
                description: "This will move \(vars.count) variable(s) from ~/.zshrc into Keychain."
            )
            if !ok {
                print("Migration cancelled.")
                return
            }
            selected = vars
        }
        let result = try ZenvCore.Migrate.apply(
            vars: selected,
            zshrcURL: paths.zshrc,
            backupDir: paths.backupDir,
            store: try LiveStore.open()
        )
        print("Migration complete!")
        print("  - Migrated: \(result.migrated.count) variable(s)")
        if !result.skipped.isEmpty {
            print("  - Skipped (already stored): \(result.skipped.joined(separator: ", "))")
        }
        if !result.failed.isEmpty {
            print("  - Failed: \(result.failed.joined(separator: ", "))")
        }
        if !result.migrated.isEmpty {
            print("  - Backup: \(result.backupPath)")
        }
        print("")
        print("Run 'source ~/.zshrc' to load the migrated variables.")
    }
}
