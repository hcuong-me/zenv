import ArgumentParser
import Foundation
import ZenvCore

@main
struct Zenv: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "zenv",
        abstract: "Secure shell environment manager for macOS Zsh",
        version: "1.0.0",
        subcommands: [Doctor.self, Env.self, Keys.self, Version.self, Put.self, Delete.self],
        defaultSubcommand: nil
    )
}

enum LiveStore {
    static func open() throws -> KeychainStore {
        let store = KeychainStore.fromEnvironment()
        _ = try store.adoptLegacyItemsIfNeeded()
        return store
    }
}

struct Version: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Show version"
    )

    func run() {
        print("zenv version 1.0.0")
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

        if fm.fileExists(atPath: paths.zshenv.path) {
            let content = try String(contentsOf: paths.zshenv, encoding: .utf8)
            let leftover = ExportParser.parseManagedLines(content)
            if !leftover.isEmpty {
                let ok: Bool
                if yes {
                    ok = true
                } else {
                    ok = try TerminalPrompt().confirm(
                        title: "Import ~/.zshenv into Keychain?",
                        description: "Found \(leftover.count) zenv export line(s). Import them and strip those lines from the file."
                    )
                }
                if ok {
                    let imported = try ZshenvImport.importAndStrip(zshenvURL: paths.zshenv, store: KeychainStore.fromEnvironment())
                    print("Imported \(imported.count) variable(s) from ~/.zshenv")
                }
            }
        }

        print("Doctor check complete!")
    }
}

