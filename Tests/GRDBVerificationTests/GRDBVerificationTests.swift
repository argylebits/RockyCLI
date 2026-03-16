import Testing
import GRDB
import Foundation

/// Verification tests for issue #78: Prove GRDB can open and read a database
/// created with Rocky's current sqlite-nio schema and ISO8601 date format.
///
/// These tests create a database using raw SQL (matching Rocky's exact schema
/// from SCHEMA.md), populate it with data using the same date format Rocky uses,
/// then read it back through GRDB to verify everything works.

// MARK: - Models (mirrors of Rocky's models, with GRDB conformances)

private struct Project: Codable, FetchableRecord, PersistableRecord, TableRecord {
    static let databaseTableName = "projects"

    let id: Int
    let parentId: Int?
    let name: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case parentId = "parent_id"
        case name
        case createdAt = "created_at"
    }

    static func databaseDateDecodingStrategy(for column: String) -> DatabaseDateDecodingStrategy {
        .iso8601
    }

    static func databaseDateEncodingStrategy(for column: String) -> DatabaseDateEncodingStrategy {
        .iso8601
    }
}

private struct Session: Codable, FetchableRecord, PersistableRecord, TableRecord {
    static let databaseTableName = "sessions"

    let id: Int
    let projectId: Int
    let startTime: Date
    let endTime: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case projectId = "project_id"
        case startTime = "start_time"
        case endTime = "end_time"
    }

    static func databaseDateDecodingStrategy(for column: String) -> DatabaseDateDecodingStrategy {
        .iso8601
    }

    static func databaseDateEncodingStrategy(for column: String) -> DatabaseDateEncodingStrategy {
        .iso8601
    }
}

// MARK: - Helpers

/// Creates an in-memory DatabaseQueue configured the way Rocky will use GRDB:
/// ISO8601 date encoding/decoding with `Z` suffix.
private func makeTestDatabase() throws -> DatabaseQueue {
    let dbQueue = try DatabaseQueue()

    // Create Rocky's exact schema from SCHEMA.md
    try dbQueue.write { db in
        try db.execute(sql: """
            CREATE TABLE IF NOT EXISTS migrations (
                version     INTEGER PRIMARY KEY,
                applied_at  DATETIME NOT NULL DEFAULT (datetime('now'))
            )
            """)
        try db.execute(sql: """
            CREATE TABLE IF NOT EXISTS projects (
                id          INTEGER  PRIMARY KEY AUTOINCREMENT,
                parent_id   INTEGER  REFERENCES projects(id),
                name        TEXT     NOT NULL UNIQUE,
                created_at  DATETIME NOT NULL DEFAULT (datetime('now'))
            )
            """)
        try db.execute(sql: """
            CREATE TABLE IF NOT EXISTS sessions (
                id          INTEGER  PRIMARY KEY AUTOINCREMENT,
                project_id  INTEGER  NOT NULL REFERENCES projects(id),
                start_time  DATETIME NOT NULL DEFAULT (datetime('now')),
                end_time    DATETIME
            )
            """)
        try db.execute(sql: "INSERT INTO migrations (version) VALUES (1)")
    }

    return dbQueue
}

private enum TestError: Error {
    case invalidDate(String)
}

/// Parse an ISO8601 date string matching Rocky's stored format.
private func parseISO8601(_ string: String) throws -> Date {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime]
    guard let date = f.date(from: string) else {
        throw TestError.invalidDate(string)
    }
    return date
}

// MARK: - Tests

@Suite("GRDB Verification — Issue #78")
struct GRDBVerificationSuite {

    @Test("GRDB opens database with Rocky schema")
    func openDatabase() throws {
        let dbQueue = try makeTestDatabase()

        // Verify tables exist
        let tables = try dbQueue.read { db in
            try String.fetchAll(db, sql: """
                SELECT name FROM sqlite_master WHERE type='table' ORDER BY name
                """)
        }
        #expect(tables.contains("projects"))
        #expect(tables.contains("sessions"))
        #expect(tables.contains("migrations"))
    }

    @Test("GRDB reads projects with ISO8601 Z dates")
    func readProjects() throws {
        let dbQueue = try makeTestDatabase()

        // Insert project with ISO8601 date (the format Rocky uses)
        try dbQueue.write { db in
            try db.execute(sql: """
                INSERT INTO projects (name, created_at) VALUES (?, ?)
                """, arguments: ["TestProject", "2026-03-16T14:30:00Z"])
        }

        // Read it back as a Project struct
        let project = try dbQueue.read { db in
            try Project.fetchOne(db, sql: "SELECT * FROM projects WHERE name = ?", arguments: ["TestProject"])
        }

        #expect(project != nil)
        #expect(project?.name == "TestProject")
        #expect(project?.parentId == nil)

        // Verify the date decoded correctly
        let expectedDate = try parseISO8601("2026-03-16T14:30:00Z")
        #expect(project?.createdAt == expectedDate)
    }

    @Test("GRDB reads sessions with ISO8601 Z dates")
    func readSessions() throws {
        let dbQueue = try makeTestDatabase()

        // Insert a project and a completed session
        try dbQueue.write { db in
            try db.execute(sql: """
                INSERT INTO projects (name, created_at) VALUES (?, ?)
                """, arguments: ["TestProject", "2026-03-16T10:00:00Z"])
            try db.execute(sql: """
                INSERT INTO sessions (project_id, start_time, end_time) VALUES (?, ?, ?)
                """, arguments: [1, "2026-03-16T14:00:00Z", "2026-03-16T15:30:00Z"])
        }

        let session = try dbQueue.read { db in
            try Session.fetchOne(db, sql: "SELECT * FROM sessions WHERE id = 1")
        }

        #expect(session != nil)
        #expect(session?.projectId == 1)

        let expectedStart = try parseISO8601("2026-03-16T14:00:00Z")
        let expectedEnd = try parseISO8601("2026-03-16T15:30:00Z")
        #expect(session?.startTime == expectedStart)
        #expect(session?.endTime == expectedEnd)
    }

    @Test("GRDB reads running sessions (NULL end_time)")
    func readRunningSessions() throws {
        let dbQueue = try makeTestDatabase()

        try dbQueue.write { db in
            try db.execute(sql: """
                INSERT INTO projects (name, created_at) VALUES (?, ?)
                """, arguments: ["TestProject", "2026-03-16T10:00:00Z"])
            try db.execute(sql: """
                INSERT INTO sessions (project_id, start_time) VALUES (?, ?)
                """, arguments: [1, "2026-03-16T14:00:00Z"])
        }

        let session = try dbQueue.read { db in
            try Session.fetchOne(db, sql:
                "SELECT * FROM sessions WHERE end_time IS NULL")
        }

        #expect(session != nil)
        #expect(session?.endTime == nil)
        let expectedStart = try parseISO8601("2026-03-16T14:00:00Z")
        #expect(session?.startTime == expectedStart)
    }

    @Test("GRDB reads JOIN with column aliasing")
    func readJoinWithAliasing() throws {
        let dbQueue = try makeTestDatabase()

        try dbQueue.write { db in
            try db.execute(sql: """
                INSERT INTO projects (name, created_at) VALUES (?, ?)
                """, arguments: ["MyProject", "2026-03-16T10:00:00Z"])
            try db.execute(sql: """
                INSERT INTO sessions (project_id, start_time) VALUES (?, ?)
                """, arguments: [1, "2026-03-16T14:00:00Z"])
        }

        // This is Rocky's exact JOIN query from getRunningWithProjects
        let rows = try dbQueue.read { db in
            try Row.fetchAll(db, sql: """
                SELECT s.*, p.id AS p_id, p.parent_id AS p_parent_id,
                       p.name AS p_name, p.created_at AS p_created_at
                FROM sessions s
                JOIN projects p ON s.project_id = p.id
                WHERE s.end_time IS NULL
                ORDER BY s.start_time ASC
                """)
        }

        #expect(rows.count == 1)

        let row = rows[0]
        // Session columns
        let session = Session(
            id: row["id"],
            projectId: row["project_id"],
            startTime: row["start_time"],
            endTime: row["end_time"]
        )
        #expect(session.projectId == 1)
        #expect(session.endTime == nil)

        // Project columns via aliases
        let projectName: String = row["p_name"]
        let projectId: Int = row["p_id"]
        #expect(projectName == "MyProject")
        #expect(projectId == 1)
    }

    @Test("GRDB handles existing migrations table")
    func existingMigrationsTable() throws {
        let dbQueue = try makeTestDatabase()

        // Verify the old migrations table exists and has data
        let version = try dbQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COALESCE(MAX(version), 0) FROM migrations")
        }
        #expect(version == 1)

        // Verify GRDB's DatabaseMigrator can run alongside the old table
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1") { db in
            // No-op — schema already exists. Use IF NOT EXISTS for safety.
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS projects (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    parent_id INTEGER REFERENCES projects(id),
                    name TEXT NOT NULL UNIQUE,
                    created_at DATETIME NOT NULL DEFAULT (datetime('now'))
                )
                """)
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS sessions (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    project_id INTEGER NOT NULL REFERENCES projects(id),
                    start_time DATETIME NOT NULL DEFAULT (datetime('now')),
                    end_time DATETIME
                )
                """)
        }
        try migrator.migrate(dbQueue)

        // Old migrations table should still be there, untouched
        let oldVersion = try dbQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COALESCE(MAX(version), 0) FROM migrations")
        }
        #expect(oldVersion == 1)

        // GRDB's own migration tracking table should also exist
        let grdbTables = try dbQueue.read { db in
            try String.fetchAll(db, sql:
                "SELECT name FROM sqlite_master WHERE type='table' AND name LIKE 'grdb%'")
        }
        #expect(!grdbTables.isEmpty)
    }

    @Test("GRDB default Date() format does NOT match Rocky's ISO8601")
    func defaultDateFormatMismatch() throws {
        let dbQueue = try makeTestDatabase()

        try dbQueue.write { db in
            try db.execute(sql: """
                INSERT INTO projects (name, created_at) VALUES (?, ?)
                """, arguments: ["DefaultFormat", Date()])
        }

        let rawString = try dbQueue.read { db in
            try String.fetchOne(db, sql:
                "SELECT created_at FROM projects WHERE name = 'DefaultFormat'")
        }

        // GRDB default: "2026-03-16 20:25:39.630" — no T, no Z
        // Rocky requires: "2026-03-16T14:30:00Z"
        #expect(rawString != nil)
        #expect(rawString?.contains("T") == false, "Default format should NOT contain T separator")
        #expect(rawString?.hasSuffix("Z") == false, "Default format should NOT end with Z")
    }

    @Test("ISO8601 date strategy encodes Date() with T and Z")
    func iso8601DateStrategyEncoding() throws {
        let dbQueue = try makeTestDatabase()

        // Use a known fixed date
        let fixedDate = try parseISO8601("2026-03-16T14:30:00Z")

        // Insert using GRDB's record insert — the model's databaseDateEncodingStrategy
        // should produce ISO8601 format automatically
        try dbQueue.write { db in
            let project = Project(id: 0, parentId: nil, name: "StrategyTest", createdAt: fixedDate)
            try project.insert(db)
        }

        // Read back the raw string to verify GRDB wrote ISO8601 with Z
        let rawString = try dbQueue.read { db in
            try String.fetchOne(db, sql:
                "SELECT created_at FROM projects WHERE name = 'StrategyTest'")
        }

        #expect(rawString != nil)
        #expect(rawString?.contains("T") == true, "ISO8601 strategy must include T separator")
        #expect(rawString?.hasSuffix("Z") == true, "ISO8601 strategy must end with Z suffix")
        #expect(rawString == "2026-03-16T14:30:00Z")
    }

    @Test("ISO8601 date strategy round-trips Date() correctly")
    func iso8601DateStrategyRoundTrip() throws {
        let dbQueue = try makeTestDatabase()

        let fixedDate = try parseISO8601("2026-03-16T14:30:00Z")

        // Write with record insert (uses encoding strategy)
        try dbQueue.write { db in
            let project = Project(id: 0, parentId: nil, name: "RoundTrip", createdAt: fixedDate)
            try project.insert(db)
        }

        // Read back with fetchOne (uses decoding strategy)
        let project = try dbQueue.read { db in
            try Project.fetchOne(db, sql:
                "SELECT * FROM projects WHERE name = 'RoundTrip'")
        }

        #expect(project?.createdAt == fixedDate)
    }

    @Test("New ISO8601 dates are readable alongside existing ISO8601 dates")
    func mixedDateReadback() throws {
        let dbQueue = try makeTestDatabase()

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        try dbQueue.write { db in
            // Simulate an existing row written by sqlite-nio (raw ISO8601 string)
            try db.execute(sql: """
                INSERT INTO projects (name, created_at) VALUES (?, ?)
                """, arguments: ["OldProject", "2026-03-10T09:00:00Z"])

            // Simulate a new row written by GRDB (Date() formatted as ISO8601)
            let newDate = try parseISO8601("2026-03-16T14:30:00Z")
            let newDateString = formatter.string(from: newDate)
            try db.execute(sql: """
                INSERT INTO projects (name, created_at) VALUES (?, ?)
                """, arguments: ["NewProject", newDateString])
        }

        let projects = try dbQueue.read { db in
            try Project.fetchAll(db, sql: "SELECT * FROM projects ORDER BY created_at ASC")
        }

        #expect(projects.count == 2)

        let oldDate = try parseISO8601("2026-03-10T09:00:00Z")
        let newDate = try parseISO8601("2026-03-16T14:30:00Z")
        #expect(projects[0].name == "OldProject")
        #expect(projects[0].createdAt == oldDate)
        #expect(projects[1].name == "NewProject")
        #expect(projects[1].createdAt == newDate)
    }
}
