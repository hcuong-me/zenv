import ArgumentParser
import Foundation
import ZenvCore

@main
struct Zenv: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "zenv",
        abstract: "Secure shell environment manager for macOS Zsh",
        version: "1.0.0",
        subcommands: [Env.self, Keys.self, Version.self, Put.self, Delete.self],
        defaultSubcommand: nil
    )
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
        let vars = try KeychainStore.fromEnvironment().exportAll()
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
        for key in try KeychainStore.fromEnvironment().listKeys() {
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
        try KeychainStore.fromEnvironment().put(key: key, value: value)
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
        try KeychainStore.fromEnvironment().delete(key: key)
    }
}
