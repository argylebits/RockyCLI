import Testing
import Foundation
@testable import RockyCore

actor TestDatabase {
    static let shared = TestDatabase()
    private var db: Database?

    func get() async throws -> Database {
        if let db { return db }
        let db = try await Database.open(at: ":memory:")
        self.db = db
        return db
    }

    func reset() async throws {
        let db = try await get()
        try await db.execute("DELETE FROM sessions")
        try await db.execute("DELETE FROM projects")
    }
}

@Suite("SQLite Integration", .serialized)
struct SQLiteIntegrationTests {

    @Test("Tables exist after migration")
    func tablesExist() async throws {
        let db = try await TestDatabase.shared.get()
        let tables = try await db.query(
            "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name"
        )
        let names = tables.compactMap { $0.column("name")?.string }
        #expect(names.contains("projects"))
        #expect(names.contains("sessions"))
        #expect(names.contains("migrations"))
    }

    @Test("Migration version is 1")
    func migrationVersion() async throws {
        let db = try await TestDatabase.shared.get()
        let rows = try await db.query("SELECT version FROM migrations")
        #expect(rows.count == 1)
        #expect(rows[0].column("version")?.integer == 1)
    }

    @Test("Migrations are idempotent")
    func migrationsIdempotent() async throws {
        let db = try await TestDatabase.shared.get()
        try await Migrations.run(on: db)
        let rows = try await db.query("SELECT version FROM migrations")
        #expect(rows.count == 1)
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
