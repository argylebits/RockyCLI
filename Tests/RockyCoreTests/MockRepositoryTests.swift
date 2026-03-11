import Testing
import Foundation
@testable import RockyCore

// MARK: - Mock Project Repository Tests

@Suite("MockProjectRepository")
struct MockProjectRepositoryTests {
    @Test("findOrCreate creates a new project")
    func createProject() async throws {
        let repo = MockProjectRepository()
        let project = try await repo.findOrCreate(name: "acme-corp")
        #expect(project.name == "acme-corp")
        #expect(project.id > 0)
        #expect(project.parentId == nil)
    }

    @Test("findOrCreate returns existing project on duplicate name")
    func findExisting() async throws {
        let repo = MockProjectRepository()
        let first = try await repo.findOrCreate(name: "acme-corp")
        let second = try await repo.findOrCreate(name: "acme-corp")
        #expect(first.id == second.id)
    }

    @Test("getByName is case-insensitive")
    func caseInsensitive() async throws {
        let repo = MockProjectRepository()
        _ = try await repo.findOrCreate(name: "Acme-Corp")
        let found = try await repo.getByName("acme-corp")
        #expect(found != nil)
        #expect(found?.name == "Acme-Corp")
    }

    @Test("getByName returns nil for unknown project")
    func unknownProject() async throws {
        let repo = MockProjectRepository()
        let found = try await repo.getByName("nonexistent")
        #expect(found == nil)
    }

    @Test("getById returns correct project")
    func getById() async throws {
        let repo = MockProjectRepository()
        let created = try await repo.findOrCreate(name: "test-project")
        let found = try await repo.getById(created.id)
        #expect(found != nil)
        #expect(found?.name == "test-project")
    }

    @Test("getById returns nil for unknown id")
    func getByIdUnknown() async throws {
        let repo = MockProjectRepository()
        let found = try await repo.getById(999)
        #expect(found == nil)
    }

    @Test("list returns all projects")
    func listProjects() async throws {
        let repo = MockProjectRepository()
        _ = try await repo.findOrCreate(name: "alpha")
        _ = try await repo.findOrCreate(name: "beta")
        _ = try await repo.findOrCreate(name: "gamma")
        let projects = try await repo.list()
        #expect(projects.count == 3)
    }

    @Test("findOrCreate deduplicates case-insensitively")
    func findOrCreateCaseInsensitive() async throws {
        let repo = MockProjectRepository()
        let first = try await repo.findOrCreate(name: "acme-corp")
        let second = try await repo.findOrCreate(name: "ACME-CORP")
        #expect(first.id == second.id)
        #expect(second.name == "acme-corp")
        let projects = try await repo.list()
        #expect(projects.count == 1)
    }

    @Test("list returns projects in creation order")
    func listOrder() async throws {
        let repo = MockProjectRepository()
        _ = try await repo.findOrCreate(name: "charlie")
        _ = try await repo.findOrCreate(name: "alpha")
        _ = try await repo.findOrCreate(name: "bravo")
        let projects = try await repo.list()
        #expect(projects[0].name == "charlie")
        #expect(projects[1].name == "alpha")
        #expect(projects[2].name == "bravo")
    }
}

// MARK: - Mock Session Repository Tests

@Suite("MockSessionRepository")
struct MockSessionRepositoryTests {
    @Test("start creates a running session")
    func startSession() async throws {
        let projectRepo = MockProjectRepository()
        let sessionRepo = MockSessionRepository(projectRepository: projectRepo)
        let project = try await projectRepo.findOrCreate(name: "acme-corp")
        try await sessionRepo.start(projectId: project.id)
        let running = try await sessionRepo.getRunning()
        #expect(running.count == 1)
        #expect(running[0].projectId == project.id)
        #expect(running[0].isRunning)
    }

    @Test("hasRunningSession returns false when nothing running")
    func hasRunningFalse() async throws {
        let projectRepo = MockProjectRepository()
        let sessionRepo = MockSessionRepository(projectRepository: projectRepo)
        let project = try await projectRepo.findOrCreate(name: "acme-corp")
        #expect(try await sessionRepo.hasRunningSession(projectId: project.id) == false)
    }

    @Test("hasRunningSession returns true after start")
    func hasRunningTrue() async throws {
        let projectRepo = MockProjectRepository()
        let sessionRepo = MockSessionRepository(projectRepository: projectRepo)
        let project = try await projectRepo.findOrCreate(name: "acme-corp")
        try await sessionRepo.start(projectId: project.id)
        #expect(try await sessionRepo.hasRunningSession(projectId: project.id) == true)
    }

    @Test("stop sets end_time on session")
    func stopSession() async throws {
        let projectRepo = MockProjectRepository()
        let sessionRepo = MockSessionRepository(projectRepository: projectRepo)
        let project = try await projectRepo.findOrCreate(name: "acme-corp")
        try await sessionRepo.start(projectId: project.id)
        let stopped = try await sessionRepo.stop(projectId: project.id)
        #expect(stopped.endTime != nil)
        #expect(!stopped.isRunning)
        let running = try await sessionRepo.getRunning()
        #expect(running.isEmpty)
    }

    @Test("stop throws when no running session")
    func stopNoRunning() async throws {
        let projectRepo = MockProjectRepository()
        let sessionRepo = MockSessionRepository(projectRepository: projectRepo)
        let project = try await projectRepo.findOrCreate(name: "acme-corp")
        await #expect(throws: RockyCoreError.self) {
            try await sessionRepo.stop(projectId: project.id)
        }
    }

    @Test("stopAll stops all running sessions")
    func stopAll() async throws {
        let projectRepo = MockProjectRepository()
        let sessionRepo = MockSessionRepository(projectRepository: projectRepo)
        let p1 = try await projectRepo.findOrCreate(name: "project-1")
        let p2 = try await projectRepo.findOrCreate(name: "project-2")
        try await sessionRepo.start(projectId: p1.id)
        try await sessionRepo.start(projectId: p2.id)
        let stopped = try await sessionRepo.stopAll()
        #expect(stopped.count == 2)
        #expect(stopped.allSatisfy { !$0.isRunning })
        let running = try await sessionRepo.getRunning()
        #expect(running.isEmpty)
    }

    @Test("stopAll returns empty array when nothing running")
    func stopAllEmpty() async throws {
        let projectRepo = MockProjectRepository()
        let sessionRepo = MockSessionRepository(projectRepository: projectRepo)
        let stopped = try await sessionRepo.stopAll()
        #expect(stopped.isEmpty)
    }

    @Test("concurrent timers on different projects")
    func concurrentTimers() async throws {
        let projectRepo = MockProjectRepository()
        let sessionRepo = MockSessionRepository(projectRepository: projectRepo)
        let p1 = try await projectRepo.findOrCreate(name: "project-1")
        let p2 = try await projectRepo.findOrCreate(name: "project-2")
        try await sessionRepo.start(projectId: p1.id)
        try await sessionRepo.start(projectId: p2.id)
        let running = try await sessionRepo.getRunning()
        #expect(running.count == 2)
    }

    @Test("stop one timer leaves other running")
    func stopOneOfTwo() async throws {
        let projectRepo = MockProjectRepository()
        let sessionRepo = MockSessionRepository(projectRepository: projectRepo)
        let p1 = try await projectRepo.findOrCreate(name: "project-1")
        let p2 = try await projectRepo.findOrCreate(name: "project-2")
        try await sessionRepo.start(projectId: p1.id)
        try await sessionRepo.start(projectId: p2.id)
        _ = try await sessionRepo.stop(projectId: p1.id)
        let running = try await sessionRepo.getRunning()
        #expect(running.count == 1)
        #expect(running[0].projectId == p2.id)
    }

    @Test("getRunningWithProjects returns session and project data")
    func runningWithProjects() async throws {
        let projectRepo = MockProjectRepository()
        let sessionRepo = MockSessionRepository(projectRepository: projectRepo)
        let project = try await projectRepo.findOrCreate(name: "acme-corp")
        try await sessionRepo.start(projectId: project.id)
        let running = try await sessionRepo.getRunningWithProjects()
        #expect(running.count == 1)
        #expect(running[0].0.projectId == project.id)
        #expect(running[0].1.name == "acme-corp")
    }

    @Test("insert creates session with explicit start/end times")
    func insertSession() async throws {
        let projectRepo = MockProjectRepository()
        let sessionRepo = MockSessionRepository(projectRepository: projectRepo)
        let cal = Calendar.current
        let project = try await projectRepo.findOrCreate(name: "test")
        let start = cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 10))!
        let end = cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 11))!
        try await sessionRepo.insert(projectId: project.id, startTime: start, endTime: end)

        let from = cal.date(from: DateComponents(year: 2026, month: 3, day: 6))!
        let to = cal.date(from: DateComponents(year: 2026, month: 3, day: 7))!
        let results = try await sessionRepo.getSessions(from: from, to: to)
        #expect(results.count == 1)
        #expect(results[0].0.startTime == start)
        #expect(results[0].0.endTime == end)
    }

    @Test("getSessions returns sessions overlapping date range")
    func getSessionsDateRange() async throws {
        let projectRepo = MockProjectRepository()
        let sessionRepo = MockSessionRepository(projectRepository: projectRepo)
        let cal = Calendar.current
        let project = try await projectRepo.findOrCreate(name: "test")

        // Fully inside range
        try await sessionRepo.insert(projectId: project.id,
            startTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 10))!,
            endTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 11))!)
        // Fully outside range (day before)
        try await sessionRepo.insert(projectId: project.id,
            startTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 5, hour: 10))!,
            endTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 5, hour: 11))!)
        // Spanning into range
        try await sessionRepo.insert(projectId: project.id,
            startTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 5, hour: 23))!,
            endTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 1))!)

        let from = cal.date(from: DateComponents(year: 2026, month: 3, day: 6))!
        let to = cal.date(from: DateComponents(year: 2026, month: 3, day: 7))!
        let results = try await sessionRepo.getSessions(from: from, to: to)

        #expect(results.count == 2)
    }

    @Test("getSessions excludes sessions outside the range")
    func getSessionsOutsideRange() async throws {
        let projectRepo = MockProjectRepository()
        let sessionRepo = MockSessionRepository(projectRepository: projectRepo)
        let cal = Calendar.current
        let project = try await projectRepo.findOrCreate(name: "test")

        try await sessionRepo.insert(projectId: project.id,
            startTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 1, hour: 10))!,
            endTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 1, hour: 11))!)

        let from = cal.date(from: DateComponents(year: 2026, month: 3, day: 6))!
        let to = cal.date(from: DateComponents(year: 2026, month: 3, day: 7))!
        let results = try await sessionRepo.getSessions(from: from, to: to)

        #expect(results.isEmpty)
    }

    @Test("stopAll only affects running sessions")
    func stopAllLeavesStoppedAlone() async throws {
        let projectRepo = MockProjectRepository()
        let sessionRepo = MockSessionRepository(projectRepository: projectRepo)
        let p1 = try await projectRepo.findOrCreate(name: "already-stopped")
        let p2 = try await projectRepo.findOrCreate(name: "still-running")
        try await sessionRepo.start(projectId: p1.id)
        _ = try await sessionRepo.stop(projectId: p1.id)
        try await sessionRepo.start(projectId: p2.id)
        let stopped = try await sessionRepo.stopAll()
        #expect(stopped.count == 1)
        #expect(stopped[0].projectId == p2.id)
    }

    @Test("getSessions filters by projectId")
    func getSessionsFilterByProject() async throws {
        let projectRepo = MockProjectRepository()
        let sessionRepo = MockSessionRepository(projectRepository: projectRepo)
        let cal = Calendar.current
        let p1 = try await projectRepo.findOrCreate(name: "included")
        let p2 = try await projectRepo.findOrCreate(name: "excluded")

        try await sessionRepo.insert(projectId: p1.id,
            startTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 10))!,
            endTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 11))!)
        try await sessionRepo.insert(projectId: p2.id,
            startTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 10))!,
            endTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 11))!)

        let from = cal.date(from: DateComponents(year: 2026, month: 3, day: 6))!
        let to = cal.date(from: DateComponents(year: 2026, month: 3, day: 7))!
        let results = try await sessionRepo.getSessions(from: from, to: to, projectId: p1.id)

        #expect(results.count == 1)
        #expect(results[0].1.name == "included")
    }
}

// MARK: - MockSessionRepository getById/update Tests

@Suite("MockSessionRepository Edit")
struct MockSessionEditTests {
    @Test("getById returns correct session")
    func getById() async throws {
        let projectRepo = MockProjectRepository()
        let sessionRepo = MockSessionRepository(projectRepository: projectRepo)
        let project = try await projectRepo.findOrCreate(name: "test")
        let cal = Calendar.current
        let start = cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 10))!
        let end = cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 11))!
        try await sessionRepo.insert(projectId: project.id, startTime: start, endTime: end)

        let sessions = try await sessionRepo.getSessions(
            from: cal.date(from: DateComponents(year: 2026, month: 3, day: 6))!,
            to: cal.date(from: DateComponents(year: 2026, month: 3, day: 7))!
        )
        let session = try await sessionRepo.getById(sessions[0].0.id)
        #expect(session != nil)
        #expect(session?.startTime == start)
    }

    @Test("getById returns nil for unknown id")
    func getByIdUnknown() async throws {
        let projectRepo = MockProjectRepository()
        let sessionRepo = MockSessionRepository(projectRepository: projectRepo)
        let session = try await sessionRepo.getById(999)
        #expect(session == nil)
    }

    @Test("update modifies session times")
    func update() async throws {
        let projectRepo = MockProjectRepository()
        let sessionRepo = MockSessionRepository(projectRepository: projectRepo)
        let project = try await projectRepo.findOrCreate(name: "test")
        let cal = Calendar.current
        let start = cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 10))!
        let end = cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 11))!
        try await sessionRepo.insert(projectId: project.id, startTime: start, endTime: end)

        let sessions = try await sessionRepo.getSessions(
            from: cal.date(from: DateComponents(year: 2026, month: 3, day: 6))!,
            to: cal.date(from: DateComponents(year: 2026, month: 3, day: 7))!
        )
        let sessionId = sessions[0].0.id

        let newStart = cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 9))!
        let newEnd = cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 12))!
        let updated = try await sessionRepo.update(id: sessionId, startTime: newStart, endTime: newEnd)

        #expect(updated.startTime == newStart)
        #expect(updated.endTime == newEnd)

        let fetched = try await sessionRepo.getById(sessionId)
        #expect(fetched?.startTime == newStart)
        #expect(fetched?.endTime == newEnd)
    }
}
