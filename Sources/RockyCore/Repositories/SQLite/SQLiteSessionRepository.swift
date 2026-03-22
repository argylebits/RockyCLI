import Foundation
import GRDB

public struct SQLiteSessionRepository: SessionRepository, Sendable {
    private let db: Database

    public init(db: Database) {
        self.db = db
    }

    public func create(projectId: Int, startTime: Date, endTime: Date?) throws -> Session {
        try db.dbQueue.write { db in
            try db.execute(
                sql: "INSERT INTO sessions (project_id, start_time, end_time) VALUES (?, ?, ?)",
                arguments: [projectId, startTime.iso8601String, endTime?.iso8601String])
            let id = Int(db.lastInsertedRowID)
            return try Session.fetchOne(db,
                sql: "SELECT * FROM sessions WHERE id = ?",
                arguments: [id])!
        }
    }

    public func get(id: Int) throws -> Session? {
        try db.dbQueue.read { db in
            try Session.fetchOne(db,
                sql: "SELECT * FROM sessions WHERE id = ?",
                arguments: [id])
        }
    }

    public func list(running: Bool? = nil, from: Date? = nil, to: Date? = nil, projectId: Int? = nil) throws -> [(Session, Project)] {
        try db.dbQueue.read { db in
            var conditions: [String] = []
            var arguments: [any DatabaseValueConvertible] = []

            if let running {
                conditions.append(running ? "s.end_time IS NULL" : "s.end_time IS NOT NULL")
            }

            if let from, let to {
                conditions.append("(s.start_time < ? AND (s.end_time > ? OR s.end_time IS NULL))")
                arguments.append(to.iso8601String)
                arguments.append(from.iso8601String)
            }

            if let projectId {
                conditions.append("s.project_id = ?")
                arguments.append(projectId)
            }

            var sql = """
                SELECT s.*, p.id AS p_id, p.parent_id AS p_parent_id,
                       p.name AS p_name, p.slug AS p_slug, p.created_at AS p_created_at
                FROM sessions s
                JOIN projects p ON s.project_id = p.id
                """

            if !conditions.isEmpty {
                sql += " WHERE " + conditions.joined(separator: " AND ")
            }

            sql += " ORDER BY s.start_time ASC"

            let rows = try Row.fetchAll(db, sql: sql, arguments: StatementArguments(arguments))
            return try rows.map { row in
                let session = try Session(row: row)
                let pCreatedAtString: String = row["p_created_at"]
                guard let pCreatedAt = Date.fromISO8601(pCreatedAtString) else {
                    throw RockyError.invalidRow("projects")
                }
                let project = Project(
                    id: row["p_id"],
                    parentId: row["p_parent_id"],
                    name: row["p_name"],
                    slug: row["p_slug"],
                    createdAt: pCreatedAt)
                return (session, project)
            }
        }
    }

    public func update(id: Int, startTime: Date, endTime: Date?) throws -> Session {
        try db.dbQueue.write { db in
            try db.execute(
                sql: "UPDATE sessions SET start_time = ?, end_time = ? WHERE id = ?",
                arguments: [startTime.iso8601String, endTime?.iso8601String, id])
            return try Session.fetchOne(db,
                sql: "SELECT * FROM sessions WHERE id = ?",
                arguments: [id])!
        }
    }
}
