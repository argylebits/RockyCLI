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

// MARK: - Session Edit Tests

@Suite("SessionService.editSession")
struct SessionEditTests {
    private func makeServices() -> (MockProjectRepository, MockSessionRepository, SessionService) {
        let projectRepo = MockProjectRepository()
        let sessionRepo = MockSessionRepository(projectRepository: projectRepo)
        let sessionService = SessionService(repository: sessionRepo)
        return (projectRepo, sessionRepo, sessionService)
    }

    private let cal = Calendar.current

    private func insertSession(
        _ sessionRepo: MockSessionRepository,
        projectId: Int,
        startHour: Int, startDay: Int = 6,
        endHour: Int, endDay: Int = 6
    ) async throws {
        let start = cal.date(from: DateComponents(year: 2026, month: 3, day: startDay, hour: startHour))!
        let end = cal.date(from: DateComponents(year: 2026, month: 3, day: endDay, hour: endHour))!
        try await sessionRepo.insert(projectId: projectId, startTime: start, endTime: end)
    }

    @Test("edit with --start only updates start, keeps stop")
    func editStartOnly() async throws {
        let (projectRepo, sessionRepo, service) = makeServices()
        let project = try await projectRepo.findOrCreate(name: "test")
        try await insertSession(sessionRepo, projectId: project.id, startHour: 10, endHour: 12)

        let all = try await sessionRepo.getSessions(
            from: cal.date(from: DateComponents(year: 2026, month: 3, day: 6))!,
            to: cal.date(from: DateComponents(year: 2026, month: 3, day: 7))!
        )
        let sessionId = all[0].0.id
        let originalEnd = all[0].0.endTime!

        let newStart = cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 9))!
        let updated = try await service.editSession(id: sessionId, newStart: newStart, newStop: nil, newDuration: nil)

        #expect(updated.startTime == newStart)
        #expect(updated.endTime == originalEnd)
    }

    @Test("edit with --stop only updates stop, keeps start")
    func editStopOnly() async throws {
        let (projectRepo, sessionRepo, service) = makeServices()
        let project = try await projectRepo.findOrCreate(name: "test")
        try await insertSession(sessionRepo, projectId: project.id, startHour: 10, endHour: 12)

        let all = try await sessionRepo.getSessions(
            from: cal.date(from: DateComponents(year: 2026, month: 3, day: 6))!,
            to: cal.date(from: DateComponents(year: 2026, month: 3, day: 7))!
        )
        let sessionId = all[0].0.id
        let originalStart = all[0].0.startTime

        let newStop = cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 14))!
        let updated = try await service.editSession(id: sessionId, newStart: nil, newStop: newStop, newDuration: nil)

        #expect(updated.startTime == originalStart)
        #expect(updated.endTime == newStop)
    }

    @Test("edit with --start + --stop updates both")
    func editStartAndStop() async throws {
        let (projectRepo, sessionRepo, service) = makeServices()
        let project = try await projectRepo.findOrCreate(name: "test")
        try await insertSession(sessionRepo, projectId: project.id, startHour: 10, endHour: 12)

        let all = try await sessionRepo.getSessions(
            from: cal.date(from: DateComponents(year: 2026, month: 3, day: 6))!,
            to: cal.date(from: DateComponents(year: 2026, month: 3, day: 7))!
        )
        let sessionId = all[0].0.id

        let newStart = cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 9))!
        let newStop = cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 11))!
        let updated = try await service.editSession(id: sessionId, newStart: newStart, newStop: newStop, newDuration: nil)

        #expect(updated.startTime == newStart)
        #expect(updated.endTime == newStop)
    }

    @Test("edit with --duration only keeps start, computes stop")
    func editDurationOnly() async throws {
        let (projectRepo, sessionRepo, service) = makeServices()
        let project = try await projectRepo.findOrCreate(name: "test")
        try await insertSession(sessionRepo, projectId: project.id, startHour: 10, endHour: 12)

        let all = try await sessionRepo.getSessions(
            from: cal.date(from: DateComponents(year: 2026, month: 3, day: 6))!,
            to: cal.date(from: DateComponents(year: 2026, month: 3, day: 7))!
        )
        let sessionId = all[0].0.id
        let originalStart = all[0].0.startTime

        let updated = try await service.editSession(id: sessionId, newStart: nil, newStop: nil, newDuration: 3600)

        #expect(updated.startTime == originalStart)
        #expect(abs(updated.endTime!.timeIntervalSince(originalStart) - 3600) < 1)
    }

    @Test("edit with --start + --duration sets start and computes stop")
    func editStartAndDuration() async throws {
        let (projectRepo, sessionRepo, service) = makeServices()
        let project = try await projectRepo.findOrCreate(name: "test")
        try await insertSession(sessionRepo, projectId: project.id, startHour: 10, endHour: 12)

        let all = try await sessionRepo.getSessions(
            from: cal.date(from: DateComponents(year: 2026, month: 3, day: 6))!,
            to: cal.date(from: DateComponents(year: 2026, month: 3, day: 7))!
        )
        let sessionId = all[0].0.id

        let newStart = cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 9))!
        let updated = try await service.editSession(id: sessionId, newStart: newStart, newStop: nil, newDuration: 5400)

        #expect(updated.startTime == newStart)
        #expect(abs(updated.endTime!.timeIntervalSince(newStart) - 5400) < 1)
    }

    @Test("edit with --stop + --duration sets stop and computes start")
    func editStopAndDuration() async throws {
        let (projectRepo, sessionRepo, service) = makeServices()
        let project = try await projectRepo.findOrCreate(name: "test")
        try await insertSession(sessionRepo, projectId: project.id, startHour: 10, endHour: 12)

        let all = try await sessionRepo.getSessions(
            from: cal.date(from: DateComponents(year: 2026, month: 3, day: 6))!,
            to: cal.date(from: DateComponents(year: 2026, month: 3, day: 7))!
        )
        let sessionId = all[0].0.id

        let newStop = cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 14))!
        let updated = try await service.editSession(id: sessionId, newStart: nil, newStop: newStop, newDuration: 7200)

        #expect(abs(updated.startTime.timeIntervalSince(newStop) + 7200) < 1)
        #expect(updated.endTime == newStop)
    }

    @Test("edit with all three flags throws overdetermined")
    func editOverdetermined() async throws {
        let (projectRepo, sessionRepo, service) = makeServices()
        let project = try await projectRepo.findOrCreate(name: "test")
        try await insertSession(sessionRepo, projectId: project.id, startHour: 10, endHour: 12)

        let all = try await sessionRepo.getSessions(
            from: cal.date(from: DateComponents(year: 2026, month: 3, day: 6))!,
            to: cal.date(from: DateComponents(year: 2026, month: 3, day: 7))!
        )
        let sessionId = all[0].0.id

        let newStart = cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 9))!
        let newStop = cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 11))!

        await #expect(throws: RockyCoreError.self) {
            try await service.editSession(id: sessionId, newStart: newStart, newStop: newStop, newDuration: 3600)
        }
    }

    @Test("edit non-existent session throws sessionNotFound")
    func editNotFound() async throws {
        let (_, _, service) = makeServices()

        await #expect(throws: RockyCoreError.self) {
            try await service.editSession(id: 999, newStart: Date(), newStop: nil, newDuration: nil)
        }
    }

    @Test("edit stop of running session throws cannotEditRunningSessionStop")
    func editRunningStop() async throws {
        let (projectRepo, sessionRepo, service) = makeServices()
        let project = try await projectRepo.findOrCreate(name: "test")
        try await sessionRepo.start(projectId: project.id)

        let running = try await sessionRepo.getRunning()
        let sessionId = running[0].id

        await #expect(throws: RockyCoreError.self) {
            try await service.editSession(id: sessionId, newStart: nil, newStop: Date(), newDuration: nil)
        }
    }

    @Test("edit start in future throws startTimeInFuture")
    func editFutureStart() async throws {
        let (projectRepo, sessionRepo, service) = makeServices()
        let project = try await projectRepo.findOrCreate(name: "test")
        try await insertSession(sessionRepo, projectId: project.id, startHour: 10, endHour: 12)

        let all = try await sessionRepo.getSessions(
            from: cal.date(from: DateComponents(year: 2026, month: 3, day: 6))!,
            to: cal.date(from: DateComponents(year: 2026, month: 3, day: 7))!
        )
        let sessionId = all[0].0.id

        let futureStart = Date().addingTimeInterval(86400)

        await #expect(throws: RockyCoreError.self) {
            try await service.editSession(id: sessionId, newStart: futureStart, newStop: nil, newDuration: nil)
        }
    }

    @Test("edit with stop before start throws stopBeforeStart")
    func editStopBeforeStart() async throws {
        let (projectRepo, sessionRepo, service) = makeServices()
        let project = try await projectRepo.findOrCreate(name: "test")
        try await insertSession(sessionRepo, projectId: project.id, startHour: 10, endHour: 12)

        let all = try await sessionRepo.getSessions(
            from: cal.date(from: DateComponents(year: 2026, month: 3, day: 6))!,
            to: cal.date(from: DateComponents(year: 2026, month: 3, day: 7))!
        )
        let sessionId = all[0].0.id

        let badStop = cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 9))!

        await #expect(throws: RockyCoreError.self) {
            try await service.editSession(id: sessionId, newStart: nil, newStop: badStop, newDuration: nil)
        }
    }

    @Test("edit with zero duration throws durationNotPositive")
    func editZeroDuration() async throws {
        let (projectRepo, sessionRepo, service) = makeServices()
        let project = try await projectRepo.findOrCreate(name: "test")
        try await insertSession(sessionRepo, projectId: project.id, startHour: 10, endHour: 12)

        let all = try await sessionRepo.getSessions(
            from: cal.date(from: DateComponents(year: 2026, month: 3, day: 6))!,
            to: cal.date(from: DateComponents(year: 2026, month: 3, day: 7))!
        )
        let sessionId = all[0].0.id

        await #expect(throws: RockyCoreError.self) {
            try await service.editSession(id: sessionId, newStart: nil, newStop: nil, newDuration: 0)
        }
    }

    @Test("edit with negative duration throws durationNotPositive")
    func editNegativeDuration() async throws {
        let (projectRepo, sessionRepo, service) = makeServices()
        let project = try await projectRepo.findOrCreate(name: "test")
        try await insertSession(sessionRepo, projectId: project.id, startHour: 10, endHour: 12)

        let all = try await sessionRepo.getSessions(
            from: cal.date(from: DateComponents(year: 2026, month: 3, day: 6))!,
            to: cal.date(from: DateComponents(year: 2026, month: 3, day: 7))!
        )
        let sessionId = all[0].0.id

        await #expect(throws: RockyCoreError.self) {
            try await service.editSession(id: sessionId, newStart: nil, newStop: nil, newDuration: -100)
        }
    }

    @Test("edit start of running session is allowed")
    func editRunningStart() async throws {
        let (projectRepo, sessionRepo, service) = makeServices()
        let project = try await projectRepo.findOrCreate(name: "test")
        try await sessionRepo.start(projectId: project.id)

        let running = try await sessionRepo.getRunning()
        let sessionId = running[0].id

        let newStart = Date().addingTimeInterval(-7200)
        let updated = try await service.editSession(id: sessionId, newStart: newStart, newStop: nil, newDuration: nil)

        #expect(abs(updated.startTime.timeIntervalSince(newStart)) < 1)
        #expect(updated.isRunning)
    }

    @Test("edit session spanning midnight")
    func editMidnightSession() async throws {
        let (projectRepo, sessionRepo, service) = makeServices()
        let project = try await projectRepo.findOrCreate(name: "test")
        try await insertSession(sessionRepo, projectId: project.id, startHour: 23, startDay: 5, endHour: 10, endDay: 6)

        let all = try await sessionRepo.getSessions(
            from: cal.date(from: DateComponents(year: 2026, month: 3, day: 5))!,
            to: cal.date(from: DateComponents(year: 2026, month: 3, day: 7))!
        )
        let sessionId = all[0].0.id

        let newStop = cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 1, minute: 30))!
        let updated = try await service.editSession(id: sessionId, newStart: nil, newStop: newStop, newDuration: nil)

        #expect(updated.endTime == newStop)
        #expect(updated.duration() == 9000) // 2.5 hours
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

// MARK: - DateTimeFormat Tests

@Suite("DateTimeFormat")
struct DateTimeFormatTests {
    private let cal = Calendar.current

    // MARK: - Parsing

    @Test("parse valid datetime string")
    func parseValid() throws {
        let date = try DateTimeFormat.parse("2026-03-10 17:30")
        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        #expect(comps.year == 2026)
        #expect(comps.month == 3)
        #expect(comps.day == 10)
        #expect(comps.hour == 17)
        #expect(comps.minute == 30)
    }

    @Test("parse midnight")
    func parseMidnight() throws {
        let date = try DateTimeFormat.parse("2026-03-10 00:00")
        let comps = cal.dateComponents([.hour, .minute], from: date)
        #expect(comps.hour == 0)
        #expect(comps.minute == 0)
    }

    @Test("parse end of day")
    func parseEndOfDay() throws {
        let date = try DateTimeFormat.parse("2026-03-10 23:59")
        let comps = cal.dateComponents([.hour, .minute], from: date)
        #expect(comps.hour == 23)
        #expect(comps.minute == 59)
    }

    @Test("parse invalid datetime throws")
    func parseInvalid() {
        #expect(throws: Error.self) {
            try DateTimeFormat.parse("not-a-date")
        }
    }

    @Test("parse empty string throws")
    func parseEmpty() {
        #expect(throws: Error.self) {
            try DateTimeFormat.parse("")
        }
    }

    @Test("parse date-only string throws (missing time)")
    func parseDateOnly() {
        #expect(throws: Error.self) {
            try DateTimeFormat.parse("2026-03-10")
        }
    }

    @Test("parseDate valid date string")
    func parseDateValid() throws {
        let date = try DateTimeFormat.parseDate("2026-03-10")
        let comps = cal.dateComponents([.year, .month, .day], from: date)
        #expect(comps.year == 2026)
        #expect(comps.month == 3)
        #expect(comps.day == 10)
    }

    @Test("parseDate invalid string throws")
    func parseDateInvalid() {
        #expect(throws: Error.self) {
            try DateTimeFormat.parseDate("not-a-date")
        }
    }

    // MARK: - Format Styles

    @Test("time format produces non-empty string")
    func timeFormat() {
        let date = cal.date(from: DateComponents(year: 2026, month: 3, day: 10, hour: 17, minute: 5))!
        let result = date.formatted(DateTimeFormat.time)
        #expect(!result.isEmpty)
        // Locale-dependent, so just check it contains the minute
        #expect(result.contains("05") || result.contains("5"))
    }

    @Test("dayOfWeek produces abbreviated weekday")
    func dayOfWeekFormat() {
        let date = cal.date(from: DateComponents(year: 2026, month: 3, day: 10))! // Tuesday
        let result = date.formatted(DateTimeFormat.dayOfWeek)
        #expect(!result.isEmpty)
        #expect(result.count <= 4) // abbreviated weekdays are short
    }

    @Test("dateWithDay includes weekday and month")
    func dateWithDayFormat() {
        let date = cal.date(from: DateComponents(year: 2026, month: 3, day: 10))!
        let result = date.formatted(DateTimeFormat.dateWithDay)
        #expect(!result.isEmpty)
        #expect(result.count >= 8) // e.g. "Tue, Mar 10"
    }

    @Test("fullDate includes year")
    func fullDateFormat() {
        let date = cal.date(from: DateComponents(year: 2026, month: 3, day: 10))!
        let result = date.formatted(DateTimeFormat.fullDate)
        #expect(result.contains("2026"))
    }

    @Test("dateWithDayYear includes year")
    func dateWithDayYearFormat() {
        let date = cal.date(from: DateComponents(year: 2026, month: 3, day: 10))!
        let result = date.formatted(DateTimeFormat.dateWithDayYear)
        #expect(result.contains("2026"))
    }

    @Test("monthYear produces full month name with year")
    func monthYearFormat() {
        let date = cal.date(from: DateComponents(year: 2026, month: 3, day: 10))!
        let result = date.formatted(DateTimeFormat.monthYear)
        #expect(result.contains("2026"))
    }

    @Test("shortMonthYear produces abbreviated month with year")
    func shortMonthYearFormat() {
        let date = cal.date(from: DateComponents(year: 2026, month: 3, day: 10))!
        let result = date.formatted(DateTimeFormat.shortMonthYear)
        #expect(result.contains("2026"))
    }

    @Test("shortDate produces day and month")
    func shortDateFormat() {
        let date = cal.date(from: DateComponents(year: 2026, month: 3, day: 10))!
        let result = date.formatted(DateTimeFormat.shortDate)
        #expect(!result.isEmpty)
        #expect(!result.contains("2026")) // no year
    }

    @Test("year produces year only")
    func yearFormat() {
        let date = cal.date(from: DateComponents(year: 2026, month: 3, day: 10))!
        let result = date.formatted(DateTimeFormat.year)
        #expect(result == "2026")
    }

    // MARK: - Period Range

    @Test("periodRange formats exclusive end date")
    func periodRange() {
        let from = cal.date(from: DateComponents(year: 2026, month: 3, day: 2))!
        let to = cal.date(from: DateComponents(year: 2026, month: 3, day: 9))! // exclusive
        let result = DateTimeFormat.periodRange(from: from, to: to)
        #expect(result.contains("—"))
        #expect(result.contains("2026")) // year appears in end date
    }

    @Test("periodRange single day range")
    func periodRangeSingleDay() {
        let from = cal.date(from: DateComponents(year: 2026, month: 3, day: 10))!
        let to = cal.date(from: DateComponents(year: 2026, month: 3, day: 11))! // exclusive, so shows Mar 10
        let result = DateTimeFormat.periodRange(from: from, to: to)
        #expect(result.contains("—"))
    }

    // MARK: - Round-trip

    @Test("parse and format round-trip preserves date components")
    func roundTrip() throws {
        let parsed = try DateTimeFormat.parse("2026-06-15 09:45")
        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: parsed)
        #expect(comps.year == 2026)
        #expect(comps.month == 6)
        #expect(comps.day == 15)
        #expect(comps.hour == 9)
        #expect(comps.minute == 45)
    }
}

// MARK: - DurationFormat Tests

@Suite("DurationFormat")
struct DurationFormatTests {
    @Test("formats zero seconds")
    func zero() {
        #expect(DurationFormat.formatted(0) == "0h 00s")
    }

    @Test("formats seconds under a minute")
    func underMinute() {
        let result = DurationFormat.formatted(30)
        #expect(result.contains("0h"))
        #expect(result.contains("30s"))
    }

    @Test("formats exactly one minute")
    func oneMinute() {
        #expect(DurationFormat.formatted(60) == "0h 01m")
    }

    @Test("formats five minutes with zero-padding")
    func fiveMinutes() {
        #expect(DurationFormat.formatted(300) == "0h 05m")
    }

    @Test("formats 45 minutes")
    func fortyFiveMinutes() {
        #expect(DurationFormat.formatted(2700) == "0h 45m")
    }

    @Test("formats exactly one hour")
    func oneHour() {
        #expect(DurationFormat.formatted(3600) == "1h 00m")
    }

    @Test("formats one hour thirty minutes")
    func oneHourThirty() {
        #expect(DurationFormat.formatted(5400) == "1h 30m")
    }

    @Test("formats two hours thirty minutes")
    func twoHoursThirty() {
        #expect(DurationFormat.formatted(9000) == "2h 30m")
    }

    @Test("formats eleven hours")
    func elevenHours() {
        #expect(DurationFormat.formatted(39600) == "11h 00m")
    }

    @Test("hoursOnly formats as hours")
    func hoursOnly() {
        #expect(DurationFormat.formatted(39600, hoursOnly: true) == "11h")
    }

    @Test("hoursOnly formats large values")
    func hoursOnlyLarge() {
        #expect(DurationFormat.formatted(108000, hoursOnly: true) == "30h")
    }

    @Test("zero-padding applies to single-digit minutes")
    func zeroPaddingSingleDigit() {
        let result = DurationFormat.formatted(3660) // 1h 1m
        #expect(result == "1h 01m")
    }

    @Test("no double-padding on two-digit minutes")
    func noDoublePadding() {
        let result = DurationFormat.formatted(4200) // 1h 10m
        #expect(result == "1h 10m")
    }
}

// MARK: - Calendar+Rocky Tests

@Suite("Calendar+Rocky")
struct CalendarRockyTests {
    private let cal = Calendar.current

    @Test("weekdayName returns correct name for Sunday (1)")
    func weekdaySunday() {
        #expect(cal.weekdayName(1) == "Sunday")
    }

    @Test("weekdayName returns correct name for Monday (2)")
    func weekdayMonday() {
        #expect(cal.weekdayName(2) == "Monday")
    }

    @Test("weekdayName returns correct name for Saturday (7)")
    func weekdaySaturday() {
        #expect(cal.weekdayName(7) == "Saturday")
    }

    @Test("weekdayName returns Unknown for invalid weekday 0")
    func weekdayInvalidZero() {
        #expect(cal.weekdayName(0) == "Unknown")
    }

    @Test("weekdayName returns Unknown for invalid weekday 8")
    func weekdayInvalidEight() {
        #expect(cal.weekdayName(8) == "Unknown")
    }

    @Test("mondayFirstVeryShortWeekdaySymbols has 7 elements")
    func mondayFirstCount() {
        #expect(cal.mondayFirstVeryShortWeekdaySymbols.count == 7)
    }

    @Test("mondayFirstVeryShortWeekdaySymbols starts with Monday")
    func mondayFirstStartsWithMonday() {
        let symbols = cal.mondayFirstVeryShortWeekdaySymbols
        let mondaySymbol = cal.veryShortStandaloneWeekdaySymbols[1] // index 1 = Monday
        #expect(symbols[0] == mondaySymbol)
    }

    @Test("mondayFirstVeryShortWeekdaySymbols ends with Sunday")
    func mondayFirstEndsWithSunday() {
        let symbols = cal.mondayFirstVeryShortWeekdaySymbols
        let sundaySymbol = cal.veryShortStandaloneWeekdaySymbols[0] // index 0 = Sunday
        #expect(symbols[6] == sundaySymbol)
    }

    @Test("monthAbbreviation returns correct month")
    func monthAbbreviationMarch() {
        let date = cal.date(from: DateComponents(year: 2026, month: 3, day: 10))!
        #expect(cal.monthAbbreviation(for: date) == "Mar")
    }

    @Test("monthAbbreviation for January")
    func monthAbbreviationJanuary() {
        let date = cal.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        #expect(cal.monthAbbreviation(for: date) == "Jan")
    }

    @Test("monthAbbreviation for December")
    func monthAbbreviationDecember() {
        let date = cal.date(from: DateComponents(year: 2026, month: 12, day: 25))!
        #expect(cal.monthAbbreviation(for: date) == "Dec")
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

// MARK: - DashboardService Tests

@Suite("DashboardService")
struct DashboardServiceTests {
    private func makeServices() -> (MockProjectRepository, MockSessionRepository, DashboardService) {
        let projectRepo = MockProjectRepository()
        let sessionRepo = MockSessionRepository(projectRepository: projectRepo)
        let dashboardService = DashboardService(sessionRepository: sessionRepo, projectRepository: projectRepo)
        return (projectRepo, sessionRepo, dashboardService)
    }

    private func date(year: Int = 2026, month: Int = 3, day: Int, hour: Int = 0) -> Date {
        var cal = Calendar.current
        cal.timeZone = .current
        return cal.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    @Test("empty data returns zero stats")
    func emptyStats() async throws {
        let (_, _, service) = makeServices()
        let now = date(day: 11, hour: 12)
        let data = try await service.generate(now: now)

        #expect(data.stats.currentStreak == 0)
        #expect(data.stats.longestStreak == 0)
        #expect(data.stats.totalHours == 0)
        #expect(data.stats.sessionsThisWeek == 0)
        #expect(data.stats.dailyAvgWeek == 0)
        #expect(data.stats.topProject == nil)
        #expect(data.stats.bestDayThisWeek == nil)
        #expect(data.stats.mostActiveWeekday == nil)
    }

    @Test("totalHours sums all session durations")
    func totalHours() async throws {
        let (projectRepo, sessionRepo, service) = makeServices()
        let project = try await projectRepo.findOrCreate(name: "test")

        // Two 2-hour sessions
        try await sessionRepo.insert(
            projectId: project.id,
            startTime: date(day: 9, hour: 10),
            endTime: date(day: 9, hour: 12)
        )
        try await sessionRepo.insert(
            projectId: project.id,
            startTime: date(day: 10, hour: 14),
            endTime: date(day: 10, hour: 16)
        )

        let now = date(day: 11, hour: 12)
        let data = try await service.generate(now: now)

        #expect(data.stats.totalHours == 4 * 3600)
    }

    @Test("sessionsThisWeek counts sessions overlapping current week")
    func sessionsThisWeek() async throws {
        let (projectRepo, sessionRepo, service) = makeServices()
        let project = try await projectRepo.findOrCreate(name: "test")

        // Week of Mar 9 (Monday) - Mar 11 is Wednesday
        // Session in this week
        try await sessionRepo.insert(
            projectId: project.id,
            startTime: date(day: 9, hour: 10),
            endTime: date(day: 9, hour: 12)
        )
        try await sessionRepo.insert(
            projectId: project.id,
            startTime: date(day: 10, hour: 10),
            endTime: date(day: 10, hour: 11)
        )
        // Session from last week (should not count)
        try await sessionRepo.insert(
            projectId: project.id,
            startTime: date(day: 6, hour: 10),
            endTime: date(day: 6, hour: 12)
        )

        let now = date(day: 11, hour: 12)
        let data = try await service.generate(now: now)

        #expect(data.stats.sessionsThisWeek == 2)
    }

    @Test("dailyAvgWeek divides week total by days elapsed")
    func dailyAvgWeek() async throws {
        let (projectRepo, sessionRepo, service) = makeServices()
        let project = try await projectRepo.findOrCreate(name: "test")

        // Mon Mar 9: 3 hours, Tue Mar 10: 3 hours = 6 hours over 2 days
        try await sessionRepo.insert(
            projectId: project.id,
            startTime: date(day: 9, hour: 9),
            endTime: date(day: 9, hour: 12)
        )
        try await sessionRepo.insert(
            projectId: project.id,
            startTime: date(day: 10, hour: 9),
            endTime: date(day: 10, hour: 12)
        )

        // Now is Wed Mar 11 at midnight = 2 days into week
        let now = date(day: 11, hour: 0)
        let data = try await service.generate(now: now)

        let expectedAvg = (6 * 3600.0) / 2.0
        #expect(abs(data.stats.dailyAvgWeek - expectedAvg) < 1)
    }

    @Test("topProject returns project with most all-time hours")
    func topProject() async throws {
        let (projectRepo, sessionRepo, service) = makeServices()
        let p1 = try await projectRepo.findOrCreate(name: "Rocky")
        let p2 = try await projectRepo.findOrCreate(name: "Other")

        // Rocky: 5 hours
        try await sessionRepo.insert(
            projectId: p1.id,
            startTime: date(day: 9, hour: 8),
            endTime: date(day: 9, hour: 13)
        )
        // Other: 2 hours
        try await sessionRepo.insert(
            projectId: p2.id,
            startTime: date(day: 9, hour: 14),
            endTime: date(day: 9, hour: 16)
        )

        let now = date(day: 11, hour: 12)
        let data = try await service.generate(now: now)

        #expect(data.stats.topProject == "Rocky")
    }

    @Test("bestDayThisWeek returns weekday with most hours")
    func bestDayThisWeek() async throws {
        let (projectRepo, sessionRepo, service) = makeServices()
        let project = try await projectRepo.findOrCreate(name: "test")

        // Mon Mar 9: 1 hour
        try await sessionRepo.insert(
            projectId: project.id,
            startTime: date(day: 9, hour: 10),
            endTime: date(day: 9, hour: 11)
        )
        // Tue Mar 10: 4 hours (should be best)
        try await sessionRepo.insert(
            projectId: project.id,
            startTime: date(day: 10, hour: 8),
            endTime: date(day: 10, hour: 12)
        )

        let now = date(day: 11, hour: 12)
        let data = try await service.generate(now: now)

        // Tuesday = weekday 3 in Calendar (1=Sun, 2=Mon, 3=Tue)
        #expect(data.stats.bestDayThisWeek == 3)
    }

    @Test("heatmap contains 31 weeks")
    func heatmapWeekCount() async throws {
        let (_, _, service) = makeServices()
        let now = date(day: 11, hour: 12)
        let data = try await service.generate(now: now)

        #expect(data.heatmap.weeks.count == 31)
    }

    @Test("sparkline contains 31 data points")
    func sparklinePointCount() async throws {
        let (_, _, service) = makeServices()
        let now = date(day: 11, hour: 12)
        let data = try await service.generate(now: now)

        #expect(data.sparkline.values.count == 31)
    }

    @Test("running session included in sessionsThisWeek")
    func runningSessionCountedInWeek() async throws {
        let (projectRepo, sessionRepo, service) = makeServices()
        let project = try await projectRepo.findOrCreate(name: "test")

        // One completed session + one running
        try await sessionRepo.insert(
            projectId: project.id,
            startTime: date(day: 9, hour: 10),
            endTime: date(day: 9, hour: 12)
        )
        try await sessionRepo.start(projectId: project.id)

        let now = date(day: 11, hour: 12)
        let data = try await service.generate(now: now)

        #expect(data.stats.sessionsThisWeek == 2)
    }

    @Test("streak calculation with consecutive days")
    func streakCalculation() async throws {
        let (projectRepo, sessionRepo, service) = makeServices()
        let project = try await projectRepo.findOrCreate(name: "test")

        // 3 consecutive days: Mar 9, 10, 11
        for day in 9...11 {
            try await sessionRepo.insert(
                projectId: project.id,
                startTime: date(day: day, hour: 10),
                endTime: date(day: day, hour: 11)
            )
        }

        let now = date(day: 11, hour: 12)
        let data = try await service.generate(now: now)

        #expect(data.stats.currentStreak == 3)
        #expect(data.stats.longestStreak == 3)
    }
}
