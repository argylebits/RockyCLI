import Foundation
import SQLiteNIO

public struct SQLiteSessionRepository: SessionRepository, Sendable {
    private let db: Database

    public init(db: Database) {
        self.db = db
    }

    public func start(projectId: Int) async throws {
        try await db.execute(
            "INSERT INTO sessions (project_id) VALUES (?)",
            [.integer(projectId)]
        )
    }

    public func hasRunningSession(projectId: Int) async throws -> Bool {
        let rows = try await db.query(
            "SELECT id FROM sessions WHERE project_id = ? AND end_time IS NULL LIMIT 1",
            [.integer(projectId)]
        )
        return !rows.isEmpty
    }

    public func stop(projectId: Int) async throws -> Session {
        let rows = try await db.query(
            "SELECT * FROM sessions WHERE project_id = ? AND end_time IS NULL LIMIT 1",
            [.integer(projectId)]
        )
        guard let row = rows.first else {
            throw RockyCoreError.noRunningTimers
        }
        let session = try row.decode(Session.self)
        try await db.execute(
            "UPDATE sessions SET end_time = strftime('%Y-%m-%dT%H:%M:%SZ', 'now') WHERE id = ?",
            [.integer(session.id)]
        )
        let updated = try await db.query(
            "SELECT * FROM sessions WHERE id = ?",
            [.integer(session.id)]
        )
        return try updated[0].decode(Session.self)
    }

    public func stopAll() async throws -> [Session] {
        let running = try await getRunning()
        var stopped: [Session] = []
        for session in running {
            try await db.execute(
                "UPDATE sessions SET end_time = strftime('%Y-%m-%dT%H:%M:%SZ', 'now') WHERE id = ?",
                [.integer(session.id)]
            )
            let updated = try await db.query(
                "SELECT * FROM sessions WHERE id = ?",
                [.integer(session.id)]
            )
            stopped.append(try updated[0].decode(Session.self))
        }
        return stopped
    }

    public func getRunning() async throws -> [Session] {
        let rows = try await db.query(
            "SELECT * FROM sessions WHERE end_time IS NULL ORDER BY start_time ASC"
        )
        return try rows.map { try $0.decode(Session.self) }
    }

    public func getRunningWithProjects() async throws -> [(Session, Project)] {
        let rows = try await db.query("""
            SELECT s.*, p.id AS p_id, p.parent_id AS p_parent_id, p.name AS p_name, p.created_at AS p_created_at
            FROM sessions s
            JOIN projects p ON s.project_id = p.id
            WHERE s.end_time IS NULL
            ORDER BY s.start_time ASC
            """)
        return try rows.map { row in
            let session = try row.decode(Session.self)
            let project = try row.decode(Project.self, prefix: "p_")
            return (session, project)
        }
    }

    public func insert(projectId: Int, startTime: Date, endTime: Date?) async throws {
        var binds: [SQLiteData] = [
            .integer(projectId),
            startTime.sqliteBind
        ]
        binds.append(endTime?.sqliteBind ?? .null)
        try await db.execute(
            "INSERT INTO sessions (project_id, start_time, end_time) VALUES (?, ?, ?)",
            binds
        )
    }

    public func getSessions(from: Date, to: Date, projectId: Int? = nil) async throws -> [(Session, Project)] {
        var sql = """
            SELECT s.*, p.id AS p_id, p.parent_id AS p_parent_id, p.name AS p_name, p.created_at AS p_created_at
            FROM sessions s
            JOIN projects p ON s.project_id = p.id
            WHERE (s.start_time < ? AND (s.end_time > ? OR s.end_time IS NULL))
            """
        var binds: [SQLiteData] = [to.sqliteBind, from.sqliteBind]

        if let projectId {
            sql += " AND s.project_id = ?"
            binds.append(.integer(projectId))
        }
        sql += " ORDER BY s.start_time ASC"

        let rows = try await db.query(sql, binds)
        return try rows.map { row in
            let session = try row.decode(Session.self)
            let project = try row.decode(Project.self, prefix: "p_")
            return (session, project)
        }
    }
}
