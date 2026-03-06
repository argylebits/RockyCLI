import ArgumentParser
import Foundation

struct Config: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Manage user preferences.",
        subcommands: [Get.self, Set.self, List.self]
    )

    struct Get: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Get a config value.")

        @Argument(help: "The config key to read.")
        var key: String

        func run() throws {
            let config = try ConfigFile.load()
            guard let value = config[key] else {
                throw CleanExit.message("Key \"\(key)\" is not set.")
            }
            print("\(key) = \(value)")
        }
    }

    struct Set: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Set a config value.")

        @Argument(help: "The config key to set.")
        var key: String

        @Argument(help: "The value to set.")
        var value: String

        func run() throws {
            var config = try ConfigFile.load()
            config[key] = value
            try ConfigFile.save(config)
            print("\(key) = \(value)")
        }
    }

    struct List: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "List all config values.")

        func run() throws {
            let config = try ConfigFile.load()
            if config.isEmpty {
                print("No config values set. Defaults:")
                print("  auto-stop = true")
                return
            }
            for (key, value) in config.sorted(by: { $0.key < $1.key }) {
                print("  \(key) = \(value)")
            }
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
