import Foundation
import GRDB

public struct SQLiteProjectRepository: ProjectRepository, Sendable {
    private let db: Database

    public init(db: Database) {
        self.db = db
    }

    public func findOrCreate(name: String) throws -> Project {
        if let existing = try getByName(name) {
            return existing
        }
        return try db.dbQueue.write { db in
            try db.execute(
                sql: "INSERT INTO projects (name, created_at) VALUES (?, ?)",
                arguments: [name, Date().iso8601String])
            let id = db.lastInsertedRowID
            return try Project.fetchOne(db,
                sql: "SELECT * FROM projects WHERE id = ?",
                arguments: [id])!
        }
    }

    public func getById(_ id: Int) throws -> Project? {
        try db.dbQueue.read { db in
            try Project.fetchOne(db,
                sql: "SELECT * FROM projects WHERE id = ?",
                arguments: [id])
        }
    }

    public func getByName(_ name: String) throws -> Project? {
        try db.dbQueue.read { db in
            try Project.fetchOne(db,
                sql: "SELECT * FROM projects WHERE name = ? COLLATE NOCASE",
                arguments: [name])
        }
    }

    public func list() throws -> [Project] {
        try db.dbQueue.read { db in
            try Project.fetchAll(db,
                sql: "SELECT * FROM projects ORDER BY created_at ASC")
        }
    }
}
