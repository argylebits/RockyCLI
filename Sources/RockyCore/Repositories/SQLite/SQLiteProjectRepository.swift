import Foundation
import GRDB

public struct SQLiteProjectRepository: ProjectRepository, Sendable {
    private let db: Database

    public init(db: Database) {
        self.db = db
    }

    public func findOrCreate(name: String) async throws -> Project {
        if let existing = try await getByName(name) {
            return existing
        }
        return try await db.dbQueue.write { db in
            try db.execute(
                sql: "INSERT INTO projects (name, created_at) VALUES (?, ?)",
                arguments: [name, Date()])
            let id = db.lastInsertedRowID
            return try Project.fetchOne(db,
                sql: "SELECT * FROM projects WHERE id = ?",
                arguments: [id])!
        }
    }

    public func getById(_ id: Int) async throws -> Project? {
        try await db.dbQueue.read { db in
            try Project.fetchOne(db,
                sql: "SELECT * FROM projects WHERE id = ?",
                arguments: [id])
        }
    }

    public func getByName(_ name: String) async throws -> Project? {
        try await db.dbQueue.read { db in
            try Project.fetchOne(db,
                sql: "SELECT * FROM projects WHERE name = ? COLLATE NOCASE",
                arguments: [name])
        }
    }

    public func list() async throws -> [Project] {
        try await db.dbQueue.read { db in
            try Project.fetchAll(db,
                sql: "SELECT * FROM projects ORDER BY created_at ASC")
        }
    }
}
