import Testing
import Foundation
@testable import RockyCore

// MARK: - Session Model (pure logic, no dependencies)

@Suite("Session Model")
struct SessionModelTests {
    @Test("duration calculates from start to end")
    func duration() {
        let start = Date()
        let end = start.addingTimeInterval(3600)
        let session = Session(id: 1, projectId: 1, startTime: start, endTime: end)
        #expect(session.duration() == 3600)
        #expect(!session.isRunning)
    }

    @Test("running session uses current time for duration")
    func runningDuration() {
        let start = Date().addingTimeInterval(-120)
        let session = Session(id: 1, projectId: 1, startTime: start, endTime: nil)
        #expect(session.isRunning)
        #expect(session.duration() >= 120)
    }
}

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

// MARK: - ReportService Tests (with mock repositories)

@Suite("ReportService")
struct ReportServiceTests {
    private func makeServices() -> (MockProjectRepository, MockSessionRepository, ReportService) {
        let projectRepo = MockProjectRepository()
        let sessionRepo = MockSessionRepository(projectRepository: projectRepo)
        let reportService = ReportService(sessionRepository: sessionRepo, projectRepository: projectRepo)
        return (projectRepo, sessionRepo, reportService)
    }

    @Test("allProjectsWithStatus returns empty for no projects")
    func statusEmpty() async throws {
        let (_, _, reportService) = makeServices()
        let statuses = try await reportService.allProjectsWithStatus()
        #expect(statuses.isEmpty)
    }

    @Test("allProjectsWithStatus shows idle projects with no sessions")
    func statusNoSessions() async throws {
        let (projectRepo, _, reportService) = makeServices()
        _ = try await projectRepo.findOrCreate(name: "idle-project")
        let statuses = try await reportService.allProjectsWithStatus()
        #expect(statuses.count == 1)
        #expect(!statuses[0].isRunning)
        #expect(statuses[0].runningSession == nil)
    }

    @Test("allProjectsWithStatus shows running projects first")
    func statusOrder() async throws {
        let (projectRepo, sessionRepo, reportService) = makeServices()
        let p1 = try await projectRepo.findOrCreate(name: "inactive")
        let p2 = try await projectRepo.findOrCreate(name: "active")
        try await sessionRepo.start(projectId: p1.id)
        _ = try await sessionRepo.stop(projectId: p1.id)
        try await sessionRepo.start(projectId: p2.id)

        let statuses = try await reportService.allProjectsWithStatus()
        #expect(statuses.count == 2)
        #expect(statuses[0].project.name == "active")
        #expect(statuses[0].isRunning)
        #expect(statuses[1].project.name == "inactive")
        #expect(!statuses[1].isRunning)
    }

    @Test("totals calculates project durations in range")
    func totals() async throws {
        let (projectRepo, sessionRepo, reportService) = makeServices()
        let cal = Calendar.current
        let project = try await projectRepo.findOrCreate(name: "test")

        try await sessionRepo.insert(projectId: project.id,
            startTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 8))!,
            endTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 9))!)

        let from = cal.date(from: DateComponents(year: 2026, month: 3, day: 6))!
        let to = cal.date(from: DateComponents(year: 2026, month: 3, day: 7))!

        let result = try await reportService.totals(from: from, to: to)
        #expect(result.entries.count == 1)
        #expect(result.entries[0].projectName == "test")
        #expect(abs(result.entries[0].duration - 3600) < 1)
    }

    @Test("totals filters by project")
    func totalsFiltered() async throws {
        let (projectRepo, sessionRepo, reportService) = makeServices()
        let cal = Calendar.current
        let p1 = try await projectRepo.findOrCreate(name: "included")
        let p2 = try await projectRepo.findOrCreate(name: "excluded")

        try await sessionRepo.insert(projectId: p1.id,
            startTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 8))!,
            endTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 9))!)
        try await sessionRepo.insert(projectId: p2.id,
            startTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 10))!,
            endTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 11))!)

        let from = cal.date(from: DateComponents(year: 2026, month: 3, day: 6))!
        let to = cal.date(from: DateComponents(year: 2026, month: 3, day: 7))!

        let result = try await reportService.totals(from: from, to: to, projectId: p1.id)
        #expect(result.entries.count == 1)
        #expect(result.entries[0].projectName == "included")
    }

    @Test("totals sums multiple sessions for same project")
    func totalsSumMultiple() async throws {
        let (projectRepo, sessionRepo, reportService) = makeServices()
        let cal = Calendar.current
        let project = try await projectRepo.findOrCreate(name: "test")

        try await sessionRepo.insert(projectId: project.id,
            startTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 8))!,
            endTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 9))!)
        try await sessionRepo.insert(projectId: project.id,
            startTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 14))!,
            endTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 15))!)

        let from = cal.date(from: DateComponents(year: 2026, month: 3, day: 6))!
        let to = cal.date(from: DateComponents(year: 2026, month: 3, day: 7))!

        let result = try await reportService.totals(from: from, to: to)
        #expect(result.entries.count == 1)
        #expect(abs(result.entries[0].duration - 7200) < 1)
    }

    @Test("totals returns empty entries for range with no sessions")
    func totalsEmpty() async throws {
        let (_, _, reportService) = makeServices()
        let cal = Calendar.current
        let from = cal.date(from: DateComponents(year: 2026, month: 3, day: 6))!
        let to = cal.date(from: DateComponents(year: 2026, month: 3, day: 7))!
        let result = try await reportService.totals(from: from, to: to)
        #expect(result.entries.isEmpty)
        #expect(result.total == 0)
    }

    @Test("totals includes running session duration up to range end")
    func totalsRunningSession() async throws {
        let (projectRepo, sessionRepo, reportService) = makeServices()
        let cal = Calendar.current
        let project = try await projectRepo.findOrCreate(name: "running")

        // Insert a running session (no endTime) that started 2 hours ago
        let startTime = Date().addingTimeInterval(-7200)
        try await sessionRepo.insert(projectId: project.id, startTime: startTime, endTime: nil)

        let from = cal.startOfDay(for: Date())
        let to = cal.date(byAdding: .day, value: 1, to: from)!

        let result = try await reportService.totals(from: from, to: to)
        #expect(result.entries.count == 1)
        #expect(result.entries[0].isRunning)
        #expect(result.entries[0].duration > 0)
    }

    @Test("totals clamps sessions that partially overlap the range")
    func partialOverlap() async throws {
        let (projectRepo, sessionRepo, reportService) = makeServices()
        let cal = Calendar.current
        let project = try await projectRepo.findOrCreate(name: "test")

        try await sessionRepo.insert(projectId: project.id,
            startTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 5, hour: 22))!,
            endTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 2))!)

        let from = cal.date(from: DateComponents(year: 2026, month: 3, day: 6))!
        let to = cal.date(from: DateComponents(year: 2026, month: 3, day: 7))!

        let result = try await reportService.totals(from: from, to: to)
        #expect(result.entries.count == 1)
        #expect(abs(result.entries[0].duration - 7200) < 1)
    }

    @Test("groupedByDay distributes sessions across correct days")
    func groupedByDay() async throws {
        let (projectRepo, sessionRepo, reportService) = makeServices()
        let cal = Calendar.current
        let project = try await projectRepo.findOrCreate(name: "test")

        try await sessionRepo.insert(projectId: project.id,
            startTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 2, hour: 10))!,
            endTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 2, hour: 12))!)
        try await sessionRepo.insert(projectId: project.id,
            startTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 4, hour: 9))!,
            endTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 4, hour: 10))!)

        let from = cal.date(from: DateComponents(year: 2026, month: 3, day: 2))!
        let to = cal.date(from: DateComponents(year: 2026, month: 3, day: 8))!

        let report = try await reportService.groupedByDay(from: from, to: to)
        #expect(report.columns.count == 6)
        #expect(report.rows.count == 1)
        #expect(abs((report.rows[0].columnDurations[0] ?? 0) - 7200) < 1)
        #expect(abs((report.rows[0].columnDurations[2] ?? 0) - 3600) < 1)
        #expect((report.rows[0].columnDurations[1] ?? 0) < 1)
    }

    @Test("session spanning midnight splits across days")
    func sessionSpanningMidnight() async throws {
        let (projectRepo, sessionRepo, reportService) = makeServices()
        let cal = Calendar.current
        let project = try await projectRepo.findOrCreate(name: "late-night")

        try await sessionRepo.insert(projectId: project.id,
            startTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 2, hour: 23))!,
            endTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 3, hour: 1))!)

        let from = cal.date(from: DateComponents(year: 2026, month: 3, day: 2))!
        let to = cal.date(from: DateComponents(year: 2026, month: 3, day: 4))!

        let report = try await reportService.groupedByDay(from: from, to: to)
        #expect(report.columns.count == 2)
        #expect(abs((report.rows[0].columnDurations[0] ?? 0) - 3600) < 1)
        #expect(abs((report.rows[0].columnDurations[1] ?? 0) - 3600) < 1)
    }

    @Test("groupedByWeek creates correct week columns")
    func groupedByWeek() async throws {
        let (projectRepo, sessionRepo, reportService) = makeServices()
        let cal = Calendar.current
        let project = try await projectRepo.findOrCreate(name: "test")

        try await sessionRepo.insert(projectId: project.id,
            startTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 2, hour: 10))!,
            endTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 2, hour: 11))!)
        try await sessionRepo.insert(projectId: project.id,
            startTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 10, hour: 10))!,
            endTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 10, hour: 11))!)

        let from = cal.date(from: DateComponents(year: 2026, month: 3, day: 2))!
        let to = cal.date(from: DateComponents(year: 2026, month: 3, day: 15))!

        let report = try await reportService.groupedByWeek(from: from, to: to)
        #expect(report.rows.count == 1)
        #expect(report.columns.count >= 2)
        #expect(abs(report.grandTotal - 7200) < 1)
    }

    @Test("groupedByMonth creates correct month columns")
    func groupedByMonth() async throws {
        let (projectRepo, sessionRepo, reportService) = makeServices()
        let cal = Calendar.current
        let project = try await projectRepo.findOrCreate(name: "test")

        try await sessionRepo.insert(projectId: project.id,
            startTime: cal.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: 10))!,
            endTime: cal.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: 12))!)
        try await sessionRepo.insert(projectId: project.id,
            startTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 1, hour: 9))!,
            endTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 1, hour: 10))!)

        let from = cal.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let to = cal.date(from: DateComponents(year: 2026, month: 4, day: 1))!

        let report = try await reportService.groupedByMonth(from: from, to: to)
        #expect(report.columns.count == 3)
        #expect(report.rows.count == 1)
        #expect(abs((report.rows[0].columnDurations[0] ?? 0) - 7200) < 1)
        #expect((report.rows[0].columnDurations[1] ?? 0) < 1)
        #expect(abs((report.rows[0].columnDurations[2] ?? 0) - 3600) < 1)
    }

    @Test("verboseSessions returns individual session rows")
    func verboseSessions() async throws {
        let (projectRepo, sessionRepo, reportService) = makeServices()
        let cal = Calendar.current
        let project = try await projectRepo.findOrCreate(name: "test")

        try await sessionRepo.insert(projectId: project.id,
            startTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 8))!,
            endTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 9))!)
        try await sessionRepo.insert(projectId: project.id,
            startTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 14))!,
            endTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 15))!)

        let from = cal.date(from: DateComponents(year: 2026, month: 3, day: 6))!
        let to = cal.date(from: DateComponents(year: 2026, month: 3, day: 7))!

        let rows = try await reportService.verboseSessions(from: from, to: to)
        #expect(rows.count == 2)
        #expect(rows[0].projectName == "test")
        #expect(rows[1].projectName == "test")
        #expect(rows[0].session.endTime != nil)
    }

    @Test("multiple projects sorted by total duration, running first")
    func multipleProjectsGrouped() async throws {
        let (projectRepo, sessionRepo, reportService) = makeServices()
        let cal = Calendar.current
        let p1 = try await projectRepo.findOrCreate(name: "alpha")
        let p2 = try await projectRepo.findOrCreate(name: "beta")

        try await sessionRepo.insert(projectId: p1.id,
            startTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 2, hour: 10))!,
            endTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 2, hour: 13))!)
        try await sessionRepo.insert(projectId: p2.id,
            startTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 2, hour: 9))!,
            endTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 2, hour: 10))!)

        let from = cal.date(from: DateComponents(year: 2026, month: 3, day: 2))!
        let to = cal.date(from: DateComponents(year: 2026, month: 3, day: 3))!

        let report = try await reportService.groupedByDay(from: from, to: to)
        #expect(report.rows.count == 2)
        #expect(report.rows[0].projectName == "alpha")
        #expect(report.rows[1].projectName == "beta")
    }
}

// MARK: - SQLite Integration Tests (real database, serialized)

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
