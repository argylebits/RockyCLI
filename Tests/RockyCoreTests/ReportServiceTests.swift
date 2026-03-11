import Testing
import Foundation
@testable import RockyCore

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
