import Testing
import Foundation
@testable import RockyCore

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

        let now = Date()

        // One completed session earlier today
        try await sessionRepo.insert(
            projectId: project.id,
            startTime: now.addingTimeInterval(-7200),
            endTime: now.addingTimeInterval(-3600)
        )
        // One running session (nil end_time) started an hour ago
        try await sessionRepo.insert(
            projectId: project.id,
            startTime: now.addingTimeInterval(-3600),
            endTime: nil
        )

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
