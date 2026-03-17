import Testing
import Foundation
@testable import RockyCore

private func makeTestDatabase() throws -> Database {
    try Database.inMemory()
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
        let created = try repo.findOrCreate(name: "round-trip-test")
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
        let project = try projectRepo.findOrCreate(name: "round-trip-test")

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
        let project = try projectRepo.findOrCreate(name: "start-stop-test")
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
        let first = try repo.findOrCreate(name: "acme-corp")
        let second = try repo.findOrCreate(name: "ACME-CORP")
        #expect(first.id == second.id)
        let projects = try repo.list()
        #expect(projects.count == 1)
    }

    @Test("Case-insensitive project lookup works in SQLite")
    func caseInsensitiveSQLite() throws {
        let db = try makeTestDatabase()
        let repo = SQLiteProjectRepository(db: db)
        _ = try repo.findOrCreate(name: "MyProject")
        let found = try repo.getByName("myproject")
        #expect(found != nil)
        #expect(found?.name == "MyProject")
    }
}
