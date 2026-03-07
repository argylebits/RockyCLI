import Foundation
import SQLiteNIO

public struct SQLiteProjectRepository: ProjectRepository, Sendable {
    private let db: Database

    public init(db: Database) {
        self.db = db
    }

    public func findOrCreate(name: String) async throws -> Project {
        if let existing = try await getByName(name) {
            return existing
        }
        try await db.execute(
            "INSERT INTO projects (name) VALUES (?)",
            [.text(name)]
        )
        let id = try await db.lastAutoincrementID()
        let rows = try await db.query(
            "SELECT * FROM projects WHERE id = ?",
            [.integer(id)]
        )
        return try rows[0].decode(Project.self)
    }

    public func getById(_ id: Int) async throws -> Project? {
        let rows = try await db.query(
            "SELECT * FROM projects WHERE id = ?",
            [.integer(id)]
        )
        guard let row = rows.first else { return nil }
        return try row.decode(Project.self)
    }

    public func getByName(_ name: String) async throws -> Project? {
        let rows = try await db.query(
            "SELECT * FROM projects WHERE name = ? COLLATE NOCASE",
            [.text(name)]
        )
        guard let row = rows.first else { return nil }
        return try row.decode(Project.self)
    }

    public func list() async throws -> [Project] {
        let rows = try await db.query(
            "SELECT * FROM projects ORDER BY created_at ASC"
        )
        return try rows.map { try $0.decode(Project.self) }
    }
}
