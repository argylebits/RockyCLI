import Foundation
import GRDB

public struct SQLiteProjectRepository: ProjectRepository, Sendable {
    private let db: Database

    public init(db: Database) {
        self.db = db
    }

    public func findOrCreate(name: String, slug: String) throws -> Project {
        if let existing = try getBySlug(slug) {
            return existing
        }
        return try db.dbQueue.write { db in
            try db.execute(
                sql: "INSERT INTO projects (name, slug, created_at) VALUES (?, ?, ?)",
                arguments: [name, slug, Date().iso8601String])
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

    public func getBySlug(_ slug: String) throws -> Project? {
        try db.dbQueue.read { db in
            try Project.fetchOne(db,
                sql: "SELECT * FROM projects WHERE slug = ?",
                arguments: [slug])
        }
    }

    public func list() throws -> [Project] {
        try db.dbQueue.read { db in
            try Project.fetchAll(db,
                sql: "SELECT * FROM projects ORDER BY created_at ASC")
        }
    }
}
