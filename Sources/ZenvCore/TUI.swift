import Darwin
import Foundation

public protocol Prompting: Sendable {
    func readLine(prompt: String) throws -> String?
    func readSecret(prompt: String) throws -> String?
    func confirm(title: String, description: String) throws -> Bool
}

public struct TerminalPrompt: Prompting {
    public init() {}

    public func readLine(prompt: String) throws -> String? {
        FileHandle.standardOutput.write(Data(prompt.utf8))
        return Swift.readLine()
    }

    public func readSecret(prompt: String) throws -> String? {
        FileHandle.standardOutput.write(Data(prompt.utf8))
        var old = termios()
        tcgetattr(STDIN_FILENO, &old)
        var next = old
        next.c_lflag &= ~tcflag_t(ECHO)
        tcsetattr(STDIN_FILENO, TCSANOW, &next)
        defer {
            tcsetattr(STDIN_FILENO, TCSANOW, &old)
            FileHandle.standardOutput.write(Data("\n".utf8))
        }
        return Swift.readLine()
    }

    public func confirm(title: String, description: String) throws -> Bool {
        print(title)
        print(description)
        FileHandle.standardOutput.write(Data("Yes / No: ".utf8))
        let line = Swift.readLine()?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return line == "y" || line == "yes"
    }
}

public enum SetForm {
    public static func run(prompt: Prompting) throws -> (key: String, value: String)? {
        guard let rawKey = try prompt.readLine(prompt: "Environment Variable Key: ") else {
            return nil
        }
        let key = rawKey.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if key.isEmpty {
            return nil
        }
        guard let value = try prompt.readSecret(prompt: "Value for \(key): ") else {
            return nil
        }
        if value.isEmpty {
            throw SetFormError.emptyValue
        }
        return (key, value)
    }
}

public enum SetFormError: Error, Equatable {
    case emptyValue
}

public enum ListTable {
    public static func render(keys: [String]) -> String {
        if keys.isEmpty {
            return "No environment variables set."
        }
        let headerKey = "KEY"
        let headerVal = "VALUE"
        let width = max(headerKey.count, keys.map(\.count).max() ?? 0)
        var rows = [
            "┌─\(String(repeating: "─", count: width + 2))─┬──────────┐",
            "│ \(headerKey.padding(toLength: width, withPad: " ", startingAt: 0)) │ \(headerVal) │",
            "├─\(String(repeating: "─", count: width + 2))─┼──────────┤",
        ]
        for key in keys {
            rows.append("│ \(key.padding(toLength: width, withPad: " ", startingAt: 0)) │ ******** │")
        }
        rows.append("└─\(String(repeating: "─", count: width + 2))─┴──────────┘")
        rows.append("")
        rows.append("\(keys.count) variable(s) stored in Keychain")
        return rows.joined(separator: "\n")
    }
}
