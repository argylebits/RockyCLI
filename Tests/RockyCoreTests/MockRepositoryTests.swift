import Testing
import Foundation
@testable import RockyCore

// MARK: - Mock Project Repository Tests

@Suite("MockProjectRepository")
struct MockProjectRepositoryTests {
    @Test("findOrCreate creates a new project")
    func createProject() throws {
        let repo = MockProjectRepository()
        let project = try repo.findOrCreate(name: "acme-corp")
        #expect(project.name == "acme-corp")
        #expect(project.id > 0)
        #expect(project.parentId == nil)
    }

    @Test("findOrCreate returns existing project on duplicate name")
    func findExisting() throws {
        let repo = MockProjectRepository()
        let first = try repo.findOrCreate(name: "acme-corp")
        let second = try repo.findOrCreate(name: "acme-corp")
        #expect(first.id == second.id)
    }

    @Test("getByName is case-insensitive")
    func caseInsensitive() throws {
        let repo = MockProjectRepository()
        _ = try repo.findOrCreate(name: "Acme-Corp")
        let found = try repo.getByName("acme-corp")
        #expect(found != nil)
        #expect(found?.name == "Acme-Corp")
    }

    @Test("getByName returns nil for unknown project")
    func unknownProject() throws {
        let repo = MockProjectRepository()
        let found = try repo.getByName("nonexistent")
        #expect(found == nil)
    }

    @Test("getById returns correct project")
    func getById() throws {
        let repo = MockProjectRepository()
        let created = try repo.findOrCreate(name: "test-project")
        let found = try repo.getById(created.id)
        #expect(found != nil)
        #expect(found?.name == "test-project")
    }

    @Test("getById returns nil for unknown id")
    func getByIdUnknown() throws {
        let repo = MockProjectRepository()
        let found = try repo.getById(999)
        #expect(found == nil)
    }

    @Test("list returns all projects")
    func listProjects() throws {
        let repo = MockProjectRepository()
        _ = try repo.findOrCreate(name: "alpha")
        _ = try repo.findOrCreate(name: "beta")
        _ = try repo.findOrCreate(name: "gamma")
        let projects = try repo.list()
        #expect(projects.count == 3)
    }

    @Test("findOrCreate deduplicates case-insensitively")
    func findOrCreateCaseInsensitive() throws {
        let repo = MockProjectRepository()
        let first = try repo.findOrCreate(name: "acme-corp")
        let second = try repo.findOrCreate(name: "ACME-CORP")
        #expect(first.id == second.id)
        #expect(second.name == "acme-corp")
        let projects = try repo.list()
        #expect(projects.count == 1)
    }

    @Test("list returns projects in creation order")
    func listOrder() throws {
        let repo = MockProjectRepository()
        _ = try repo.findOrCreate(name: "charlie")
        _ = try repo.findOrCreate(name: "alpha")
        _ = try repo.findOrCreate(name: "bravo")
        let projects = try repo.list()
        #expect(projects[0].name == "charlie")
        #expect(projects[1].name == "alpha")
        #expect(projects[2].name == "bravo")
    }
}

// MARK: - Mock Session Repository Tests

@Suite("MockSessionRepository")
struct MockSessionRepositoryTests {
    @Test("start creates a running session")
    func startSession() throws {
        let projectRepo = MockProjectRepository()
        let sessionRepo = MockSessionRepository(projectRepository: projectRepo)
        let project = try projectRepo.findOrCreate(name: "acme-corp")
        try sessionRepo.start(projectId: project.id)
        let running = try sessionRepo.getRunning()
        #expect(running.count == 1)
        #expect(running[0].projectId == project.id)
        #expect(running[0].isRunning)
    }

    @Test("hasRunningSession returns false when nothing running")
    func hasRunningFalse() throws {
        let projectRepo = MockProjectRepository()
        let sessionRepo = MockSessionRepository(projectRepository: projectRepo)
        let project = try projectRepo.findOrCreate(name: "acme-corp")
        #expect(try sessionRepo.hasRunningSession(projectId: project.id) == false)
    }

    @Test("hasRunningSession returns true after start")
    func hasRunningTrue() throws {
        let projectRepo = MockProjectRepository()
        let sessionRepo = MockSessionRepository(projectRepository: projectRepo)
        let project = try projectRepo.findOrCreate(name: "acme-corp")
        try sessionRepo.start(projectId: project.id)
        #expect(try sessionRepo.hasRunningSession(projectId: project.id) == true)
    }

    @Test("stop sets end_time on session")
    func stopSession() throws {
        let projectRepo = MockProjectRepository()
        let sessionRepo = MockSessionRepository(projectRepository: projectRepo)
        let project = try projectRepo.findOrCreate(name: "acme-corp")
        try sessionRepo.start(projectId: project.id)
        let stopped = try sessionRepo.stop(projectId: project.id)
        #expect(stopped.endTime != nil)
        #expect(!stopped.isRunning)
        let running = try sessionRepo.getRunning()
        #expect(running.isEmpty)
    }

    @Test("stop throws when no running session")
    func stopNoRunning() throws {
        let projectRepo = MockProjectRepository()
        let sessionRepo = MockSessionRepository(projectRepository: projectRepo)
        let project = try projectRepo.findOrCreate(name: "acme-corp")
        #expect(throws: RockyCoreError.self) {
            try sessionRepo.stop(projectId: project.id)
        }
    }

    @Test("stopAll stops all running sessions")
    func stopAll() throws {
        let projectRepo = MockProjectRepository()
        let sessionRepo = MockSessionRepository(projectRepository: projectRepo)
        let p1 = try projectRepo.findOrCreate(name: "project-1")
        let p2 = try projectRepo.findOrCreate(name: "project-2")
        try sessionRepo.start(projectId: p1.id)
        try sessionRepo.start(projectId: p2.id)
        let stopped = try sessionRepo.stopAll()
        #expect(stopped.count == 2)
        #expect(stopped.allSatisfy { !$0.isRunning })
        let running = try sessionRepo.getRunning()
        #expect(running.isEmpty)
    }

    @Test("stopAll returns empty array when nothing running")
    func stopAllEmpty() throws {
        let projectRepo = MockProjectRepository()
        let sessionRepo = MockSessionRepository(projectRepository: projectRepo)
        let stopped = try sessionRepo.stopAll()
        #expect(stopped.isEmpty)
    }

    @Test("concurrent timers on different projects")
    func concurrentTimers() throws {
        let projectRepo = MockProjectRepository()
        let sessionRepo = MockSessionRepository(projectRepository: projectRepo)
        let p1 = try projectRepo.findOrCreate(name: "project-1")
        let p2 = try projectRepo.findOrCreate(name: "project-2")
        try sessionRepo.start(projectId: p1.id)
        try sessionRepo.start(projectId: p2.id)
        let running = try sessionRepo.getRunning()
        #expect(running.count == 2)
    }

    @Test("stop one timer leaves other running")
    func stopOneOfTwo() throws {
        let projectRepo = MockProjectRepository()
        let sessionRepo = MockSessionRepository(projectRepository: projectRepo)
        let p1 = try projectRepo.findOrCreate(name: "project-1")
        let p2 = try projectRepo.findOrCreate(name: "project-2")
        try sessionRepo.start(projectId: p1.id)
        try sessionRepo.start(projectId: p2.id)
        _ = try sessionRepo.stop(projectId: p1.id)
        let running = try sessionRepo.getRunning()
        #expect(running.count == 1)
        #expect(running[0].projectId == p2.id)
    }

    @Test("getRunningWithProjects returns session and project data")
    func runningWithProjects() throws {
        let projectRepo = MockProjectRepository()
        let sessionRepo = MockSessionRepository(projectRepository: projectRepo)
        let project = try projectRepo.findOrCreate(name: "acme-corp")
        try sessionRepo.start(projectId: project.id)
        let running = try sessionRepo.getRunningWithProjects()
        #expect(running.count == 1)
        #expect(running[0].0.projectId == project.id)
        #expect(running[0].1.name == "acme-corp")
    }

    @Test("insert creates session with explicit start/end times")
    func insertSession() throws {
        let projectRepo = MockProjectRepository()
        let sessionRepo = MockSessionRepository(projectRepository: projectRepo)
        let cal = Calendar.current
        let project = try projectRepo.findOrCreate(name: "test")
        let start = cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 10))!
        let end = cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 11))!
        try sessionRepo.insert(projectId: project.id, startTime: start, endTime: end)

        let from = cal.date(from: DateComponents(year: 2026, month: 3, day: 6))!
        let to = cal.date(from: DateComponents(year: 2026, month: 3, day: 7))!
        let results = try sessionRepo.getSessions(from: from, to: to)
        #expect(results.count == 1)
        #expect(results[0].0.startTime == start)
        #expect(results[0].0.endTime == end)
    }

    @Test("getSessions returns sessions overlapping date range")
    func getSessionsDateRange() throws {
        let projectRepo = MockProjectRepository()
        let sessionRepo = MockSessionRepository(projectRepository: projectRepo)
        let cal = Calendar.current
        let project = try projectRepo.findOrCreate(name: "test")

        // Fully inside range
        try sessionRepo.insert(projectId: project.id,
            startTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 10))!,
            endTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 11))!)
        // Fully outside range (day before)
        try sessionRepo.insert(projectId: project.id,
            startTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 5, hour: 10))!,
            endTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 5, hour: 11))!)
        // Spanning into range
        try sessionRepo.insert(projectId: project.id,
            startTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 5, hour: 23))!,
            endTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 1))!)

        let from = cal.date(from: DateComponents(year: 2026, month: 3, day: 6))!
        let to = cal.date(from: DateComponents(year: 2026, month: 3, day: 7))!
        let results = try sessionRepo.getSessions(from: from, to: to)

        #expect(results.count == 2)
    }

    @Test("getSessions excludes sessions outside the range")
    func getSessionsOutsideRange() throws {
        let projectRepo = MockProjectRepository()
        let sessionRepo = MockSessionRepository(projectRepository: projectRepo)
        let cal = Calendar.current
        let project = try projectRepo.findOrCreate(name: "test")

        try sessionRepo.insert(projectId: project.id,
            startTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 1, hour: 10))!,
            endTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 1, hour: 11))!)

        let from = cal.date(from: DateComponents(year: 2026, month: 3, day: 6))!
        let to = cal.date(from: DateComponents(year: 2026, month: 3, day: 7))!
        let results = try sessionRepo.getSessions(from: from, to: to)

        #expect(results.isEmpty)
    }

    @Test("stopAll only affects running sessions")
    func stopAllLeavesStoppedAlone() throws {
        let projectRepo = MockProjectRepository()
        let sessionRepo = MockSessionRepository(projectRepository: projectRepo)
        let p1 = try projectRepo.findOrCreate(name: "already-stopped")
        let p2 = try projectRepo.findOrCreate(name: "still-running")
        try sessionRepo.start(projectId: p1.id)
        _ = try sessionRepo.stop(projectId: p1.id)
        try sessionRepo.start(projectId: p2.id)
        let stopped = try sessionRepo.stopAll()
        #expect(stopped.count == 1)
        #expect(stopped[0].projectId == p2.id)
    }

    @Test("getSessions filters by projectId")
    func getSessionsFilterByProject() throws {
        let projectRepo = MockProjectRepository()
        let sessionRepo = MockSessionRepository(projectRepository: projectRepo)
        let cal = Calendar.current
        let p1 = try projectRepo.findOrCreate(name: "included")
        let p2 = try projectRepo.findOrCreate(name: "excluded")

        try sessionRepo.insert(projectId: p1.id,
            startTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 10))!,
            endTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 11))!)
        try sessionRepo.insert(projectId: p2.id,
            startTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 10))!,
            endTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 11))!)

        let from = cal.date(from: DateComponents(year: 2026, month: 3, day: 6))!
        let to = cal.date(from: DateComponents(year: 2026, month: 3, day: 7))!
        let results = try sessionRepo.getSessions(from: from, to: to, projectId: p1.id)

        #expect(results.count == 1)
        #expect(results[0].1.name == "included")
    }
}

// MARK: - MockSessionRepository getById/update Tests

@Suite("MockSessionRepository Edit")
struct MockSessionEditTests {
    @Test("getById returns correct session")
    func getById() throws {
        let projectRepo = MockProjectRepository()
        let sessionRepo = MockSessionRepository(projectRepository: projectRepo)
        let project = try projectRepo.findOrCreate(name: "test")
        let cal = Calendar.current
        let start = cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 10))!
        let end = cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 11))!
        try sessionRepo.insert(projectId: project.id, startTime: start, endTime: end)

        let sessions = try sessionRepo.getSessions(
            from: cal.date(from: DateComponents(year: 2026, month: 3, day: 6))!,
            to: cal.date(from: DateComponents(year: 2026, month: 3, day: 7))!
        )
        let session = try sessionRepo.getById(sessions[0].0.id)
        #expect(session != nil)
        #expect(session?.startTime == start)
    }

    @Test("getById returns nil for unknown id")
    func getByIdUnknown() throws {
        let projectRepo = MockProjectRepository()
        let sessionRepo = MockSessionRepository(projectRepository: projectRepo)
        let session = try sessionRepo.getById(999)
        #expect(session == nil)
    }

    @Test("update modifies session times")
    func update() throws {
        let projectRepo = MockProjectRepository()
        let sessionRepo = MockSessionRepository(projectRepository: projectRepo)
        let project = try projectRepo.findOrCreate(name: "test")
        let cal = Calendar.current
        let start = cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 10))!
        let end = cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 11))!
        try sessionRepo.insert(projectId: project.id, startTime: start, endTime: end)

        let sessions = try sessionRepo.getSessions(
            from: cal.date(from: DateComponents(year: 2026, month: 3, day: 6))!,
            to: cal.date(from: DateComponents(year: 2026, month: 3, day: 7))!
        )
        let sessionId = sessions[0].0.id

        let newStart = cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 9))!
        let newEnd = cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 12))!
        let updated = try sessionRepo.update(id: sessionId, startTime: newStart, endTime: newEnd)

        #expect(updated.startTime == newStart)
        #expect(updated.endTime == newEnd)

        let fetched = try sessionRepo.getById(sessionId)
        #expect(fetched?.startTime == newStart)
        #expect(fetched?.endTime == newEnd)
    }
}
