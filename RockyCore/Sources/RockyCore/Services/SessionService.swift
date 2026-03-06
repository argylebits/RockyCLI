import Foundation
import SQLiteNIO

public struct SessionService: Sendable {
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
        let session = try Session(row: row)
        try await db.execute(
            "UPDATE sessions SET end_time = datetime('now') WHERE id = ?",
            [.integer(session.id)]
        )
        // Re-fetch to get the end_time
        let updated = try await db.query(
            "SELECT * FROM sessions WHERE id = ?",
            [.integer(session.id)]
        )
        return try Session(row: updated[0])
    }

    public func stopAll() async throws -> [Session] {
        let running = try await getRunning()
        var stopped: [Session] = []
        for session in running {
            try await db.execute(
                "UPDATE sessions SET end_time = datetime('now') WHERE id = ?",
                [.integer(session.id)]
            )
            let updated = try await db.query(
                "SELECT * FROM sessions WHERE id = ?",
                [.integer(session.id)]
            )
            stopped.append(try Session(row: updated[0]))
        }
        return stopped
    }

    public func getRunning() async throws -> [Session] {
        let rows = try await db.query(
            "SELECT * FROM sessions WHERE end_time IS NULL ORDER BY start_time ASC"
        )
        return try rows.map { try Session(row: $0) }
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
            let session = try Session(row: row)
            guard let pId = row.column("p_id")?.integer,
                  let pName = row.column("p_name")?.string,
                  let pCreatedAtStr = row.column("p_created_at")?.string else {
                throw RockyCoreError.invalidRow("session+project join")
            }
            let project = Project(
                id: pId,
                parentId: row.column("p_parent_id")?.integer,
                name: pName,
                createdAt: try DateFormatter.sqlite.parseOrThrow(pCreatedAtStr)
            )
            return (session, project)
        }
    }

    public func getSessions(from: Date, to: Date, projectId: Int? = nil) async throws -> [(Session, Project)] {
        let fromStr = DateFormatter.sqlite.string(from: from)
        let toStr = DateFormatter.sqlite.string(from: to)

        var sql = """
            SELECT s.*, p.id AS p_id, p.parent_id AS p_parent_id, p.name AS p_name, p.created_at AS p_created_at
            FROM sessions s
            JOIN projects p ON s.project_id = p.id
            WHERE (s.start_time < ? AND (s.end_time > ? OR s.end_time IS NULL))
            """
        var binds: [SQLiteData] = [.text(toStr), .text(fromStr)]

        if let projectId {
            sql += " AND s.project_id = ?"
            binds.append(.integer(projectId))
        }
        sql += " ORDER BY s.start_time ASC"

        let rows = try await db.query(sql, binds)
        return try rows.map { row in
            let session = try Session(row: row)
            guard let pId = row.column("p_id")?.integer,
                  let pName = row.column("p_name")?.string,
                  let pCreatedAtStr = row.column("p_created_at")?.string else {
                throw RockyCoreError.invalidRow("session+project join")
            }
            let project = Project(
                id: pId,
                parentId: row.column("p_parent_id")?.integer,
                name: pName,
                createdAt: try DateFormatter.sqlite.parseOrThrow(pCreatedAtStr)
            )
            return (session, project)
        }
    }
}
