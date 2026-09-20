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
