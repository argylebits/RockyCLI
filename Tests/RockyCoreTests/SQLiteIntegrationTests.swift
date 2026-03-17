import Testing
import Foundation
@testable import RockyCore

actor TestDatabase {
    static let shared = TestDatabase()
    private var db: Database?

    func get() throws -> Database {
        if let db { return db }
        let db = try Database.inMemory()
        self.db = db
        return db
    }

    func reset() async throws {
        let db = try get()
        try await db.dbQueue.write { db in
            try db.execute(sql: "DELETE FROM sessions")
            try db.execute(sql: "DELETE FROM projects")
        }
    }
}

@Suite("SQLite Integration", .serialized)
struct SQLiteIntegrationTests {

    @Test("Tables exist after migration")
    func tablesExist() async throws {
        let db = try await TestDatabase.shared.get()
        let tables = try await db.dbQueue.read { db in
            try String.fetchAll(db, sql:
                "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")
        }
        #expect(tables.contains("projects"))
        #expect(tables.contains("sessions"))
    }

    @Test("GRDB migrations table exists")
    func grdbMigrationsExist() async throws {
        let db = try await TestDatabase.shared.get()
        let tables = try await db.dbQueue.read { db in
            try String.fetchAll(db, sql:
                "SELECT name FROM sqlite_master WHERE type='table' AND name LIKE 'grdb%'")
        }
        #expect(!tables.isEmpty)
    }

    @Test("Migrations are idempotent")
    func migrationsIdempotent() async throws {
        let db = try await TestDatabase.shared.get()
        try Migrations.run(on: db)
        let tables = try await db.dbQueue.read { db in
            try String.fetchAll(db, sql:
                "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")
        }
        #expect(tables.contains("projects"))
        #expect(tables.contains("sessions"))
    }

    @Test("SQLiteProjectRepository round-trips project data")
    func projectRoundTrip() async throws {
        try await TestDatabase.shared.reset()
        let db = try await TestDatabase.shared.get()
        let repo = SQLiteProjectRepository(db: db)
        let created = try await repo.findOrCreate(name: "round-trip-test")
        let found = try await repo.getById(created.id)
        #expect(found != nil)
        #expect(found?.name == "round-trip-test")
        #expect(found?.id == created.id)
    }

    @Test("SQLiteSessionRepository round-trips session data")
    func sessionRoundTrip() async throws {
        try await TestDatabase.shared.reset()
        let db = try await TestDatabase.shared.get()
        let projectRepo = SQLiteProjectRepository(db: db)
        let sessionRepo = SQLiteSessionRepository(db: db)
        let cal = Calendar.current
        let project = try await projectRepo.findOrCreate(name: "round-trip-test")

        let startTime = cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 10))!
        let endTime = cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 11))!
        try await sessionRepo.insert(projectId: project.id, startTime: startTime, endTime: endTime)

        let from = cal.date(from: DateComponents(year: 2026, month: 3, day: 6))!
        let to = cal.date(from: DateComponents(year: 2026, month: 3, day: 7))!
        let results = try await sessionRepo.getSessions(from: from, to: to)

        #expect(results.count == 1)
        #expect(abs(results[0].0.startTime.timeIntervalSince(startTime)) < 1)
        #expect(abs(results[0].0.endTime!.timeIntervalSince(endTime)) < 1)
    }

    @Test("SQLite start and stop round-trip")
    func startStopRoundTrip() async throws {
        try await TestDatabase.shared.reset()
        let db = try await TestDatabase.shared.get()
        let projectRepo = SQLiteProjectRepository(db: db)
        let sessionRepo = SQLiteSessionRepository(db: db)
        let project = try await projectRepo.findOrCreate(name: "start-stop-test")
        try await sessionRepo.start(projectId: project.id)

        let running = try await sessionRepo.getRunning()
        #expect(running.count == 1)
        #expect(running[0].isRunning)

        let stopped = try await sessionRepo.stop(projectId: project.id)
        #expect(!stopped.isRunning)
        #expect(stopped.endTime != nil)

        let afterStop = try await sessionRepo.getRunning()
        #expect(afterStop.isEmpty)
    }

    @Test("SQLite findOrCreate deduplicates case-insensitively")
    func findOrCreateCaseInsensitiveSQLite() async throws {
        try await TestDatabase.shared.reset()
        let db = try await TestDatabase.shared.get()
        let repo = SQLiteProjectRepository(db: db)
        let first = try await repo.findOrCreate(name: "acme-corp")
        let second = try await repo.findOrCreate(name: "ACME-CORP")
        #expect(first.id == second.id)
        let projects = try await repo.list()
        #expect(projects.count == 1)
    }

    @Test("Case-insensitive project lookup works in SQLite")
    func caseInsensitiveSQLite() async throws {
        try await TestDatabase.shared.reset()
        let db = try await TestDatabase.shared.get()
        let repo = SQLiteProjectRepository(db: db)
        _ = try await repo.findOrCreate(name: "MyProject")
        let found = try await repo.getByName("myproject")
        #expect(found != nil)
        #expect(found?.name == "MyProject")
    }
}
