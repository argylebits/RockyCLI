import Foundation
import GRDB

public final class Database: Sendable {
    public let dbQueue: DatabaseQueue

    private init(dbQueue: DatabaseQueue) {
        self.dbQueue = dbQueue
    }

    public static func open(trace: (@Sendable (String) -> Void)? = nil) throws -> Database {
        let dbDir = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent(".rocky")

        if !FileManager.default.fileExists(atPath: dbDir.path) {
            try FileManager.default.createDirectory(at: dbDir, withIntermediateDirectories: true)
        }

        let dbPath = dbDir.appendingPathComponent("rocky.db").path
        let database = Database(dbQueue: try DatabaseQueue(path: dbPath, configuration: makeConfig(trace: trace)))
        try Migrations.run(on: database)
        return database
    }

    public static func inMemory(trace: (@Sendable (String) -> Void)? = nil) throws -> Database {
        let database = Database(dbQueue: try DatabaseQueue(configuration: makeConfig(trace: trace)))
        try Migrations.run(on: database)
        return database
    }

    private static func makeConfig(trace: (@Sendable (String) -> Void)?) -> Configuration {
        var config = Configuration()
        if let trace {
            config.prepareDatabase { db in
                db.trace { event in
                    trace(String(describing: event))
                }
            }
        }
        return config
    }
}
