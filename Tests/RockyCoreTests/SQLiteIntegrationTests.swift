import Testing
import Foundation
import GRDB
@testable import RockyCore

private func makeTestDatabase() throws -> RockyCore.Database {
    try RockyCore.Database.inMemory()
}

@Suite("SQLite Integration", .serialized)
struct SQLiteIntegrationTests {

    @Test("Tables exist after migration")
    func tablesExist() throws {
        let db = try makeTestDatabase()
        let tables = try db.dbQueue.read { db in
            try String.fetchAll(db, sql:
                "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")
        }
        #expect(tables.contains("projects"))
        #expect(tables.contains("sessions"))
    }

    @Test("GRDB migrations table exists")
    func grdbMigrationsExist() throws {
        let db = try makeTestDatabase()
        let tables = try db.dbQueue.read { db in
            try String.fetchAll(db, sql:
                "SELECT name FROM sqlite_master WHERE type='table' AND name LIKE 'grdb%'")
        }
        #expect(!tables.isEmpty)
    }

    @Test("Migrations are idempotent")
    func migrationsIdempotent() throws {
        let db = try makeTestDatabase()
        try Migrations.run(on: db)
        let tables = try db.dbQueue.read { db in
            try String.fetchAll(db, sql:
                "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")
        }
        #expect(tables.contains("projects"))
        #expect(tables.contains("sessions"))
    }

    @Test("SQLiteProjectRepository round-trips project data")
    func projectRoundTrip() throws {
        let db = try makeTestDatabase()
        let repo = SQLiteProjectRepository(db: db)
        let created = try repo.findOrCreate(name: "round-trip-test", slug: "round-trip-test".slugified)
        let found = try repo.getById(created.id)
        #expect(found != nil)
        #expect(found?.name == "round-trip-test")
        #expect(found?.id == created.id)
    }

    @Test("SQLiteSessionRepository round-trips session data")
    func sessionRoundTrip() throws {
        let db = try makeTestDatabase()
        let projectRepo = SQLiteProjectRepository(db: db)
        let sessionRepo = SQLiteSessionRepository(db: db)
        let cal = Calendar.current
        let project = try projectRepo.findOrCreate(name: "round-trip-test", slug: "round-trip-test".slugified)

        let startTime = cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 10))!
        let endTime = cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 11))!
        try sessionRepo.insert(projectId: project.id, startTime: startTime, endTime: endTime)

        let from = cal.date(from: DateComponents(year: 2026, month: 3, day: 6))!
        let to = cal.date(from: DateComponents(year: 2026, month: 3, day: 7))!
        let results = try sessionRepo.getSessions(from: from, to: to)

        #expect(results.count == 1)
        #expect(abs(results[0].0.startTime.timeIntervalSince(startTime)) < 1)
        #expect(abs(results[0].0.endTime!.timeIntervalSince(endTime)) < 1)
    }

    @Test("SQLite start and stop round-trip")
    func startStopRoundTrip() throws {
        let db = try makeTestDatabase()
        let projectRepo = SQLiteProjectRepository(db: db)
        let sessionRepo = SQLiteSessionRepository(db: db)
        let project = try projectRepo.findOrCreate(name: "start-stop-test", slug: "start-stop-test".slugified)
        try sessionRepo.start(projectId: project.id)

        let running = try sessionRepo.getRunning()
        #expect(running.count == 1)
        #expect(running[0].isRunning)

        let stopped = try sessionRepo.stop(projectId: project.id)
        #expect(!stopped.isRunning)
        #expect(stopped.endTime != nil)

        let afterStop = try sessionRepo.getRunning()
        #expect(afterStop.isEmpty)
    }

    @Test("SQLite findOrCreate deduplicates case-insensitively")
    func findOrCreateCaseInsensitiveSQLite() throws {
        let db = try makeTestDatabase()
        let repo = SQLiteProjectRepository(db: db)
        let first = try repo.findOrCreate(name: "acme-corp", slug: "acme-corp".slugified)
        let second = try repo.findOrCreate(name: "ACME-CORP", slug: "ACME-CORP".slugified)
        #expect(first.id == second.id)
        let projects = try repo.list()
        #expect(projects.count == 1)
    }

    @Test("v2 migration preserves existing projects and populates slugs")
    func v2MigrationPreservesData() throws {
        // Create a raw database with only the v1 schema
        let config = Configuration()
        let dbQueue = try DatabaseQueue(configuration: config)
        try dbQueue.write { db in
            try db.execute(sql: """
                CREATE TABLE projects (
                    id          INTEGER PRIMARY KEY AUTOINCREMENT,
                    parent_id   INTEGER REFERENCES projects(id),
                    name        TEXT    NOT NULL UNIQUE,
                    created_at  TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
                )
                """)
            try db.execute(sql: """
                CREATE TABLE sessions (
                    id          INTEGER PRIMARY KEY AUTOINCREMENT,
                    project_id  INTEGER NOT NULL REFERENCES projects(id),
                    start_time  TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
                    end_time    TEXT
                )
                """)

            // Insert v1 data (no slug column)
            try db.execute(sql: "INSERT INTO projects (name, created_at) VALUES (?, ?)",
                arguments: ["Acme Corp", "2026-01-15T10:00:00Z"])
            try db.execute(sql: "INSERT INTO projects (name, created_at) VALUES (?, ?)",
                arguments: ["side-project", "2026-02-20T14:00:00Z"])

            // Insert sessions linked to projects
            try db.execute(sql: "INSERT INTO sessions (project_id, start_time, end_time) VALUES (?, ?, ?)",
                arguments: [1, "2026-03-06T10:00:00Z", "2026-03-06T12:00:00Z"])
            try db.execute(sql: "INSERT INTO sessions (project_id, start_time, end_time) VALUES (?, ?, ?)",
                arguments: [2, "2026-03-06T14:00:00Z", "2026-03-06T15:00:00Z"])
        }

        // Run full migrations (v1 is already applied manually, but v2 should add slug)
        let database = try RockyCore.Database.fromQueue(dbQueue)

        // Verify projects survived with slugs
        let repo = SQLiteProjectRepository(db: database)
        let projects = try repo.list()
        #expect(projects.count == 2)

        let acme = projects.first { $0.name == "Acme Corp" }
        #expect(acme != nil)
        #expect(acme?.slug == "acme-corp")
        #expect(acme?.id == 1)

        let side = projects.first { $0.name == "side-project" }
        #expect(side != nil)
        #expect(side?.slug == "side-project")

        // Verify sessions still linked
        let sessionRepo = SQLiteSessionRepository(db: database)
        let cal = Calendar.current
        let from = cal.date(from: DateComponents(year: 2026, month: 3, day: 6))!
        let to = cal.date(from: DateComponents(year: 2026, month: 3, day: 7))!
        let sessions = try sessionRepo.getSessions(from: from, to: to)
        #expect(sessions.count == 2)
        #expect(sessions[0].1.name == "Acme Corp")
        #expect(sessions[1].1.name == "side-project")
    }

    @Test("SQLite getBySlug returns project by exact slug match")
    func getBySlugSQLite() throws {
        let db = try makeTestDatabase()
        let repo = SQLiteProjectRepository(db: db)
        _ = try repo.findOrCreate(name: "MyProject", slug: "MyProject".slugified)
        let found = try repo.getBySlug("myproject")
        #expect(found != nil)
        #expect(found?.name == "MyProject")
    }
}
