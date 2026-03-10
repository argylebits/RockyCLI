import Foundation
import SQLiteNIO
import NIOPosix
import Logging

public final class Database: Sendable {
    private let connection: SQLiteConnection
    private let threadPool: NIOThreadPool
    private let eventLoopGroup: MultiThreadedEventLoopGroup

    public var db: SQLiteConnection { connection }

    private init(connection: SQLiteConnection, threadPool: NIOThreadPool, eventLoopGroup: MultiThreadedEventLoopGroup) {
        self.connection = connection
        self.threadPool = threadPool
        self.eventLoopGroup = eventLoopGroup
    }

    public static func open() async throws -> Database {
        let dbDir = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent(".rocky")

        if !FileManager.default.fileExists(atPath: dbDir.path) {
            try FileManager.default.createDirectory(at: dbDir, withIntermediateDirectories: true)
        }

        let dbPath = dbDir.appendingPathComponent("rocky.db").path
        return try await open(at: dbPath)
    }

    public static func open(at path: String) async throws -> Database {
        let threadPool = NIOThreadPool(numberOfThreads: 1)
        threadPool.start()

        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let logger = Logger(label: "rocky")

        let storage: SQLiteConnection.Storage = (path == ":memory:") ? .memory : .file(path: path)

        let connection = try await SQLiteConnection.open(
            storage: storage,
            threadPool: threadPool,
            logger: logger,
            on: eventLoopGroup.any()
        )

        let database = Database(connection: connection, threadPool: threadPool, eventLoopGroup: eventLoopGroup)
        try await Migrations.run(on: database)
        return database
    }

    public func query(_ sql: String, _ binds: [SQLiteData] = []) async throws -> [SQLiteRow] {
        nonisolated(unsafe) var rows: [SQLiteRow] = []
        try await connection.query(sql, binds) { row in
            rows.append(row)
        }
        return rows
    }

    public func execute(_ sql: String, _ binds: [SQLiteData] = []) async throws {
        try await connection.query(sql, binds) { _ in }
    }

    public func lastAutoincrementID() async throws -> Int {
        try await connection.lastAutoincrementID()
    }

    public func close() async throws {
        try await connection.close()
        try await threadPool.shutdownGracefully()
        try await eventLoopGroup.shutdownGracefully()
    }
}
