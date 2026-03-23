import ArgumentParser
import Foundation
import RockyCore

struct Config: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Manage user preferences.",
        subcommands: [Get.self, Set.self, List.self]
    )

    struct Get: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Get a config value.")

        @Argument(help: "The config key to read.")
        var key: String

        @OptionGroup var outputOptions: OutputOptions

        func run() throws {
            do {
                let result = try execute()
                output(result, options: outputOptions)
            } catch let error as RockyError {
                outputError(error, options: outputOptions)
                throw ExitCode.failure
            }
        }

        @discardableResult
        func execute() throws -> CommandResult {
            let config = try ConfigFile.load()
            guard let value = config[key] else {
                throw RockyError.configKeyNotSet(key)
            }
            return .configValue(key: key, value: value)
        }
    }

    struct Set: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Set a config value.")

        @Argument(help: "The config key to set.")
        var key: String

        @Argument(help: "The value to set.")
        var value: String

        @OptionGroup var outputOptions: OutputOptions

        func run() throws {
            do {
                let result = try execute()
                output(result, options: outputOptions)
            } catch let error as RockyError {
                outputError(error, options: outputOptions)
                throw ExitCode.failure
            }
        }

        @discardableResult
        func execute() throws -> CommandResult {
            var config = try ConfigFile.load()
            config[key] = value
            try ConfigFile.save(config)
            return .configValue(key: key, value: value)
        }
    }

    struct List: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "List all config values.")

        @OptionGroup var outputOptions: OutputOptions

        func run() throws {
            do {
                let result = try execute()
                output(result, options: outputOptions)
            } catch let error as RockyError {
                outputError(error, options: outputOptions)
                throw ExitCode.failure
            }
        }

        @discardableResult
        func execute() throws -> CommandResult {
            let config = try ConfigFile.load()
            let entries = config.sorted(by: { $0.key < $1.key }).map { (key: $0.key, value: $0.value) }
            return .configList(entries: entries)
        }
    }
}

enum ConfigFile {
    private static var configPath: URL {
        FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent(".rocky/config.json")
    }

    static func load() throws -> [String: String] {
        let path = configPath
        guard FileManager.default.fileExists(atPath: path.path) else {
            return [:]
        }
        let data = try Data(contentsOf: path)
        return try JSONDecoder().decode([String: String].self, from: data)
    }

    static func save(_ config: [String: String]) throws {
        let dir = configPath.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        let data = try JSONEncoder().encode(config)
        try data.write(to: configPath)
    }

    static func getBool(_ key: String, default defaultValue: Bool) throws -> Bool {
        let config = try load()
        guard let value = config[key] else { return defaultValue }
        return value == "true"
    }
}
