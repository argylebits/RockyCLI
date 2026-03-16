import Foundation
import GRDB

public final class Database: Sendable {
    public let dbQueue: DatabaseQueue

    private init(dbQueue: DatabaseQueue) {
        self.dbQueue = dbQueue
    }

    public static func open() throws -> Database {
        let dbDir = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent(".rocky")

        if !FileManager.default.fileExists(atPath: dbDir.path) {
            try FileManager.default.createDirectory(at: dbDir, withIntermediateDirectories: true)
        }

        let dbPath = dbDir.appendingPathComponent("rocky.db").path
        let database = Database(dbQueue: try DatabaseQueue(path: dbPath))
        try Migrations.run(on: database)
        return database
    }

    public static func inMemory() throws -> Database {
        let database = Database(dbQueue: try DatabaseQueue())
        try Migrations.run(on: database)
        return database
    }
}
