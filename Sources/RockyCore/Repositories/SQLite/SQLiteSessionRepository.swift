import Foundation
import GRDB

public struct SQLiteSessionRepository: SessionRepository, Sendable {
    private let db: Database

    public init(db: Database) {
        self.db = db
    }

    public func start(projectId: Int) throws {
        try db.dbQueue.write { db in
            try db.execute(
                sql: "INSERT INTO sessions (project_id, start_time) VALUES (?, ?)",
                arguments: [projectId, Date().iso8601String])
        }
    }

    public func hasRunningSession(projectId: Int) throws -> Bool {
        try db.dbQueue.read { db in
            let count = try Int.fetchOne(db,
                sql: "SELECT COUNT(*) FROM sessions WHERE project_id = ? AND end_time IS NULL LIMIT 1",
                arguments: [projectId])
            return (count ?? 0) > 0
        }
    }

    public func stop(projectId: Int) throws -> Session {
        try db.dbQueue.write { db in
            guard let session = try Session.fetchOne(db,
                sql: "SELECT * FROM sessions WHERE project_id = ? AND end_time IS NULL LIMIT 1",
                arguments: [projectId]) else {
                throw RockyCoreError.noRunningTimers
            }
            try db.execute(
                sql: "UPDATE sessions SET end_time = ? WHERE id = ?",
                arguments: [Date().iso8601String, session.id])
            return try Session.fetchOne(db,
                sql: "SELECT * FROM sessions WHERE id = ?",
                arguments: [session.id])!
        }
    }

    public func stopAll() throws -> [Session] {
        try db.dbQueue.write { db in
            let running = try Session.fetchAll(db,
                sql: "SELECT * FROM sessions WHERE end_time IS NULL ORDER BY start_time ASC")
            let now = Date().iso8601String
            var stopped: [Session] = []
            for session in running {
                try db.execute(
                    sql: "UPDATE sessions SET end_time = ? WHERE id = ?",
                    arguments: [now, session.id])
                let updated = try Session.fetchOne(db,
                    sql: "SELECT * FROM sessions WHERE id = ?",
                    arguments: [session.id])!
                stopped.append(updated)
            }
            return stopped
        }
    }

    public func getRunning() throws -> [Session] {
        try db.dbQueue.read { db in
            try Session.fetchAll(db,
                sql: "SELECT * FROM sessions WHERE end_time IS NULL ORDER BY start_time ASC")
        }
    }

    public func getRunningWithProjects() throws -> [(Session, Project)] {
        try db.dbQueue.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT s.*, p.id AS p_id, p.parent_id AS p_parent_id,
                       p.name AS p_name, p.created_at AS p_created_at
                FROM sessions s
                JOIN projects p ON s.project_id = p.id
                WHERE s.end_time IS NULL
                ORDER BY s.start_time ASC
                """)
            return try rows.map { row in
                let session = try Session(row: row)
                let pCreatedAtString: String = row["p_created_at"]
                guard let pCreatedAt = Date.fromISO8601(pCreatedAtString) else {
                    throw RockyCoreError.invalidRow("projects")
                }
                let project = Project(
                    id: row["p_id"],
                    parentId: row["p_parent_id"],
                    name: row["p_name"],
                    createdAt: pCreatedAt)
                return (session, project)
            }
        }
    }

    public func insert(projectId: Int, startTime: Date, endTime: Date?) throws {
        try db.dbQueue.write { db in
            try db.execute(
                sql: "INSERT INTO sessions (project_id, start_time, end_time) VALUES (?, ?, ?)",
                arguments: [projectId, startTime.iso8601String, endTime?.iso8601String])
        }
    }

    public func getById(_ id: Int) throws -> Session? {
        try db.dbQueue.read { db in
            try Session.fetchOne(db,
                sql: "SELECT * FROM sessions WHERE id = ?",
                arguments: [id])
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

    public func getSessions(from: Date, to: Date, projectId: Int? = nil) throws -> [(Session, Project)] {
        try db.dbQueue.read { db in
            var sql = """
                SELECT s.*, p.id AS p_id, p.parent_id AS p_parent_id,
                       p.name AS p_name, p.created_at AS p_created_at
                FROM sessions s
                JOIN projects p ON s.project_id = p.id
                WHERE (s.start_time < ? AND (s.end_time > ? OR s.end_time IS NULL))
                """
            var arguments: [any DatabaseValueConvertible] = [to.iso8601String, from.iso8601String]

            if let projectId {
                sql += " AND s.project_id = ?"
                arguments.append(projectId)
            }
            sql += " ORDER BY s.start_time ASC"

            let rows = try Row.fetchAll(db, sql: sql, arguments: StatementArguments(arguments))
            return try rows.map { row in
                let session = try Session(row: row)
                let pCreatedAtString: String = row["p_created_at"]
                guard let pCreatedAt = Date.fromISO8601(pCreatedAtString) else {
                    throw RockyCoreError.invalidRow("projects")
                }
                let project = Project(
                    id: row["p_id"],
                    parentId: row["p_parent_id"],
                    name: row["p_name"],
                    createdAt: pCreatedAt)
                return (session, project)
            }
        }
    }
}
