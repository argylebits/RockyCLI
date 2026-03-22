import Foundation
import GRDB

public struct SQLiteProjectRepository: ProjectRepository, Sendable {
    private let db: Database

    public init(db: Database) {
        self.db = db
    }

    public func create(name: String, slug: String) throws -> Project {
        try db.dbQueue.write { db in
            if let _ = try Project.fetchOne(db,
                sql: "SELECT * FROM projects WHERE slug = ?",
                arguments: [slug]) {
                throw RockyError.projectAlreadyExists(name)
            }
            try db.execute(
                sql: "INSERT INTO projects (name, slug, created_at) VALUES (?, ?, ?)",
                arguments: [name, slug, Date().iso8601String])
            let id = db.lastInsertedRowID
            return try Project.fetchOne(db,
                sql: "SELECT * FROM projects WHERE id = ?",
                arguments: [id])!
        }
    }

    // Keep findOrCreate for backward compatibility with session-layer callers
    public func findOrCreate(name: String, slug: String) throws -> Project {
        if let existing = try get(slug: slug) {
            return existing
        }
        return try create(name: name, slug: slug)
    }

    public func get(id: Int) throws -> Project? {
        try db.dbQueue.read { db in
            try Project.fetchOne(db,
                sql: "SELECT * FROM projects WHERE id = ?",
                arguments: [id])
        }
    }

    public func get(slug: String) throws -> Project? {
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

    public func update(id: Int, name: String, slug: String) throws -> Project {
        try db.dbQueue.write { db in
            if let existing = try Project.fetchOne(db,
                sql: "SELECT * FROM projects WHERE slug = ? AND id != ?",
                arguments: [slug, id]) {
                throw RockyError.projectAlreadyExists(existing.name)
            }
            try db.execute(
                sql: "UPDATE projects SET name = ?, slug = ? WHERE id = ?",
                arguments: [name, slug, id])
            guard let updated = try Project.fetchOne(db,
                sql: "SELECT * FROM projects WHERE id = ?",
                arguments: [id]) else {
                throw RockyError.projectNotFound(String(id))
            }
            return updated
        }
    }
}
