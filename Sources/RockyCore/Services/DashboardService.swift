import Foundation

public struct DashboardService: Sendable {
    private let sessionRepository: any SessionRepository
    private let projectRepository: any ProjectRepository

    public init(sessionRepository: any SessionRepository, projectRepository: any ProjectRepository) {
        self.sessionRepository = sessionRepository
        self.projectRepository = projectRepository
    }

    public func generate(now: Date = Date()) throws -> DashboardData {
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Monday (per DECISIONS.md)

        // Key date boundaries
        let thisWeekStart = startOfWeek(for: now, calendar: calendar)
        let lastWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeekStart)!
        let thisMonthStart = startOfMonth(for: now, calendar: calendar)
        let lastMonthStart = calendar.date(byAdding: .month, value: -1, to: thisMonthStart)!
        let thisYearStart = startOfYear(for: now, calendar: calendar)
        let heatmapStart = calendar.date(byAdding: .weekOfYear, value: -30, to: thisWeekStart)!

        // Fetch sessions for recent range (covers summaries, heatmap, sparkline, peak hours, distribution)
        let earliestNeeded = [heatmapStart, thisYearStart, lastMonthStart, lastWeekStart].min()!
        let recentSessions = try sessionRepository.getSessions(from: earliestNeeded, to: now, projectId: nil)

        // Fetch full history for streaks and all-time stats
        let allSessions = try sessionRepository.getSessions(
            from: Date(timeIntervalSince1970: 0), to: now, projectId: nil
        )

        // Running timers
        let runningPairs = try sessionRepository.getRunningWithProjects()
        let runningTimers = runningPairs.map { session, project in
            RunningTimer(projectName: project.name, duration: session.duration(at: now))
        }

        let timeSummary = computeTimeSummary(
            sessions: recentSessions, now: now,
            thisWeekStart: thisWeekStart, lastWeekStart: lastWeekStart,
            thisMonthStart: thisMonthStart, lastMonthStart: lastMonthStart,
            thisYearStart: thisYearStart
        )

        let heatmap = computeHeatmap(
            sessions: recentSessions, now: now, calendar: calendar,
            heatmapStart: heatmapStart
        )

        let sparkline = computeSparkline(
            sessions: recentSessions, now: now, calendar: calendar,
            start: heatmapStart
        )

        let projectDistribution = computeProjectDistribution(
            sessions: recentSessions, now: now,
            from: thisWeekStart, to: now
        )

        let peakHours = computePeakHours(
            sessions: recentSessions, now: now, calendar: calendar,
            from: heatmapStart, to: now
        )

        let weekSessions = recentSessions.filter { session, _ in
            session.startTime >= thisWeekStart || (session.endTime ?? now) > thisWeekStart
        }
        let stats = computeStats(
            sessions: allSessions, weekSessions: weekSessions,
            now: now, calendar: calendar, thisWeekStart: thisWeekStart
        )

        return DashboardData(
            runningTimers: runningTimers,
            timeSummary: timeSummary,
            heatmap: heatmap,
            sparkline: sparkline,
            projectDistribution: projectDistribution,
            peakHours: peakHours,
            stats: stats
        )
    }

    // MARK: - Time Summary

    private func computeTimeSummary(
        sessions: [(Session, Project)],
        now: Date,
        thisWeekStart: Date,
        lastWeekStart: Date,
        thisMonthStart: Date,
        lastMonthStart: Date,
        thisYearStart: Date
    ) -> TimeSummary {
        TimeSummary(
            thisWeek: totalDuration(of: sessions, from: thisWeekStart, to: now, now: now),
            lastWeek: totalDuration(of: sessions, from: lastWeekStart, to: thisWeekStart, now: now),
            thisMonth: totalDuration(of: sessions, from: thisMonthStart, to: now, now: now),
            lastMonth: totalDuration(of: sessions, from: lastMonthStart, to: thisMonthStart, now: now),
            thisYear: totalDuration(of: sessions, from: thisYearStart, to: now, now: now)
        )
    }

    private func totalDuration(
        of sessions: [(Session, Project)], from: Date, to: Date, now: Date
    ) -> TimeInterval {
        var total: TimeInterval = 0
        for (session, _) in sessions {
            let sessionEnd = session.endTime ?? now
            let overlapStart = max(session.startTime, from)
            let overlapEnd = min(sessionEnd, to)
            if overlapEnd > overlapStart {
                total += overlapEnd.timeIntervalSince(overlapStart)
            }
        }
        return total
    }

    // MARK: - Heatmap

    private func computeHeatmap(
        sessions: [(Session, Project)],
        now: Date,
        calendar: Calendar,
        heatmapStart: Date
    ) -> HeatmapData {
        // Accumulate daily durations
        var dailyDurations: [DateComponents: TimeInterval] = [:]

        for (session, _) in sessions {
            let sessionEnd = session.endTime ?? now
            let clampedStart = max(session.startTime, heatmapStart)
            let clampedEnd = min(sessionEnd, now)
            guard clampedEnd > clampedStart else { continue }

            // Distribute duration across day boundaries
            var dayStart = calendar.startOfDay(for: clampedStart)
            while dayStart < clampedEnd {
                let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
                let overlapStart = max(clampedStart, dayStart)
                let overlapEnd = min(clampedEnd, dayEnd)
                if overlapEnd > overlapStart {
                    let key = calendar.dateComponents([.year, .month, .day], from: dayStart)
                    dailyDurations[key, default: 0] += overlapEnd.timeIntervalSince(overlapStart)
                }
                dayStart = dayEnd
            }
        }

        // Build week structures (Mon-Sun rows)
        let today = calendar.startOfDay(for: now)
        var weeks: [HeatmapWeek] = []
        var weekStart = heatmapStart

        while weekStart <= today {
            var days: [DayActivity] = []
            for dayOffset in 0..<7 {
                let date = calendar.date(byAdding: .day, value: dayOffset, to: weekStart)!
                let key = calendar.dateComponents([.year, .month, .day], from: date)
                let duration = dailyDurations[key] ?? 0
                let isFuture = date > today
                days.append(DayActivity(date: date, duration: duration, isFuture: isFuture))
            }
            weeks.append(HeatmapWeek(weekStartDate: weekStart, days: days))
            weekStart = calendar.date(byAdding: .weekOfYear, value: 1, to: weekStart)!
        }

        return HeatmapData(weeks: weeks)
    }

    // MARK: - Sparkline

    private func computeSparkline(
        sessions: [(Session, Project)],
        now: Date,
        calendar: Calendar,
        start: Date
    ) -> SparklineData {
        var points: [SparklinePoint] = []
        var weekStart = start

        while weekStart < now {
            let weekEnd = min(
                calendar.date(byAdding: .weekOfYear, value: 1, to: weekStart)!,
                now
            )
            let total = totalDuration(of: sessions, from: weekStart, to: weekEnd, now: now)
            points.append(SparklinePoint(weekStartDate: weekStart, value: total))
            weekStart = calendar.date(byAdding: .weekOfYear, value: 1, to: weekStart)!
        }

        return SparklineData(values: points)
    }

    // MARK: - Project Distribution

    private func computeProjectDistribution(
        sessions: [(Session, Project)],
        now: Date,
        from: Date,
        to: Date
    ) -> [ProjectDistributionEntry] {
        var projectDurations: [String: TimeInterval] = [:]
        var projectRunning: [String: Bool] = [:]

        for (session, project) in sessions {
            let sessionEnd = session.endTime ?? now
            let overlapStart = max(session.startTime, from)
            let overlapEnd = min(sessionEnd, to)
            if overlapEnd > overlapStart {
                projectDurations[project.name, default: 0] += overlapEnd.timeIntervalSince(overlapStart)
                if session.isRunning {
                    projectRunning[project.name] = true
                }
            }
        }

        let grandTotal = projectDurations.values.reduce(0, +)
        guard grandTotal > 0 else { return [] }

        return projectDurations
            .map { name, duration in
                ProjectDistributionEntry(
                    projectName: name,
                    duration: duration,
                    percentage: (duration / grandTotal) * 100,
                    isRunning: projectRunning[name] ?? false
                )
            }
            .sorted { a, b in
                if a.isRunning != b.isRunning { return a.isRunning }
                return a.duration > b.duration
            }
    }

    // MARK: - Peak Hours

    private func computePeakHours(
        sessions: [(Session, Project)],
        now: Date,
        calendar: Calendar,
        from: Date,
        to: Date
    ) -> [Int: TimeInterval] {
        var hourBuckets: [Int: TimeInterval] = [:]

        for (session, _) in sessions {
            let sessionEnd = session.endTime ?? now
            let clampedStart = max(session.startTime, from)
            let clampedEnd = min(sessionEnd, to)
            guard clampedEnd > clampedStart else { continue }

            // Walk through each hour boundary the session spans
            var current = clampedStart
            while current < clampedEnd {
                let hour = calendar.component(.hour, from: current)
                let hourComponents = calendar.dateComponents([.year, .month, .day, .hour], from: current)
                let hourStart = calendar.date(from: hourComponents)!
                let hourEnd = calendar.date(byAdding: .hour, value: 1, to: hourStart)!

                let overlapStart = max(current, hourStart)
                let overlapEnd = min(clampedEnd, hourEnd)
                if overlapEnd > overlapStart {
                    hourBuckets[hour, default: 0] += overlapEnd.timeIntervalSince(overlapStart)
                }
                current = hourEnd
            }
        }

        return hourBuckets
    }

    // MARK: - Stats

    private func computeStats(
        sessions: [(Session, Project)],
        weekSessions: [(Session, Project)],
        now: Date,
        calendar: Calendar,
        thisWeekStart: Date
    ) -> DashboardStats {
        guard !sessions.isEmpty else {
            return DashboardStats(
                currentStreak: 0,
                longestStreak: 0,
                averageSessionDuration: 0,
                longestSession: nil,
                mostActiveWeekday: nil,
                dailyAvgWeek: 0,
                sessionsThisWeek: 0,
                totalHours: 0,
                topProject: nil,
                bestDayThisWeek: nil
            )
        }

        // Average and longest session
        var totalDuration: TimeInterval = 0
        var longest: LongestSessionInfo?

        for (session, project) in sessions {
            let dur = session.duration(at: now)
            totalDuration += dur
            if longest == nil || dur > longest!.duration {
                longest = LongestSessionInfo(
                    duration: dur,
                    projectName: project.name,
                    date: session.startTime
                )
            }
        }

        let averageDuration = totalDuration / Double(sessions.count)

        // Collect unique dates and weekday durations
        var datesWithSessions = Set<DateComponents>()
        var weekdayDurations: [Int: TimeInterval] = [:]

        for (session, _) in sessions {
            let sessionEnd = session.endTime ?? now

            var dayStart = calendar.startOfDay(for: session.startTime)
            while dayStart < sessionEnd {
                let key = calendar.dateComponents([.year, .month, .day], from: dayStart)
                datesWithSessions.insert(key)

                let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
                let overlapStart = max(session.startTime, dayStart)
                let overlapEnd = min(sessionEnd, dayEnd)
                if overlapEnd > overlapStart {
                    let weekday = calendar.component(.weekday, from: dayStart)
                    weekdayDurations[weekday, default: 0] += overlapEnd.timeIntervalSince(overlapStart)
                }
                dayStart = dayEnd
            }
        }

        // Sort unique dates for streak calculation
        let sortedDates = datesWithSessions
            .compactMap { calendar.date(from: $0) }
            .map { calendar.startOfDay(for: $0) }
            .sorted()

        let today = calendar.startOfDay(for: now)
        var currentStreak = 0
        var longestStreak = 0

        if !sortedDates.isEmpty {
            // Find all streaks
            var streak = 1
            for i in 1..<sortedDates.count {
                let prev = sortedDates[i - 1]
                let curr = sortedDates[i]
                let daysBetween = calendar.dateComponents([.day], from: prev, to: curr).day ?? 0
                if daysBetween == 1 {
                    streak += 1
                } else if daysBetween > 1 {
                    longestStreak = max(longestStreak, streak)
                    streak = 1
                }
                // daysBetween == 0 means duplicate date (shouldn't happen with Set, but safe)
            }
            longestStreak = max(longestStreak, streak)

            // Current streak: walk backwards from today (or yesterday if no sessions today)
            let lastDate = sortedDates.last!
            let daysSinceLastSession = calendar.dateComponents([.day], from: lastDate, to: today).day ?? 0

            if daysSinceLastSession <= 1 {
                currentStreak = 1
                var checkDate = lastDate
                for i in stride(from: sortedDates.count - 2, through: 0, by: -1) {
                    let prevDate = sortedDates[i]
                    let daysBetween = calendar.dateComponents([.day], from: prevDate, to: checkDate).day ?? 0
                    if daysBetween == 1 {
                        currentStreak += 1
                        checkDate = prevDate
                    } else {
                        break
                    }
                }
            }
        }

        let mostActiveWeekday = weekdayDurations.max(by: { $0.value < $1.value })?.key

        // Weekly stats
        let weekSessionCount = weekSessions.count
        let weekTotal = weekSessions.reduce(0.0) { sum, pair in
            let (session, _) = pair
            let sessionEnd = session.endTime ?? now
            let overlapStart = max(session.startTime, thisWeekStart)
            let overlapEnd = min(sessionEnd, now)
            return overlapEnd > overlapStart ? sum + overlapEnd.timeIntervalSince(overlapStart) : sum
        }
        let daysIntoWeek = max(1, calendar.dateComponents([.day], from: thisWeekStart, to: now).day ?? 1)
        let dailyAvgWeek = weekTotal / Double(daysIntoWeek)

        // Top project (all time by total duration)
        var projectTotals: [String: TimeInterval] = [:]
        for (session, project) in sessions {
            projectTotals[project.name, default: 0] += session.duration(at: now)
        }
        let topProject = projectTotals.max(by: { $0.value < $1.value })?.key

        // Best day this week (weekday with most hours)
        var weekdayDurationsThisWeek: [Int: TimeInterval] = [:]
        for (session, _) in weekSessions {
            let sessionEnd = session.endTime ?? now
            var dayStart = max(calendar.startOfDay(for: session.startTime), thisWeekStart)
            while dayStart < sessionEnd && dayStart < now {
                let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
                let overlapStart = max(session.startTime, dayStart)
                let overlapEnd = min(sessionEnd, dayEnd)
                if overlapEnd > overlapStart {
                    let wd = calendar.component(.weekday, from: dayStart)
                    weekdayDurationsThisWeek[wd, default: 0] += overlapEnd.timeIntervalSince(overlapStart)
                }
                dayStart = dayEnd
            }
        }
        let bestDayThisWeek = weekdayDurationsThisWeek.max(by: { $0.value < $1.value })?.key

        return DashboardStats(
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            averageSessionDuration: averageDuration,
            longestSession: longest,
            mostActiveWeekday: mostActiveWeekday,
            dailyAvgWeek: dailyAvgWeek,
            sessionsThisWeek: weekSessionCount,
            totalHours: totalDuration,
            topProject: topProject,
            bestDayThisWeek: bestDayThisWeek
        )
    }

    // MARK: - Date Helpers

    private func startOfWeek(for date: Date, calendar: Calendar) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)!.start
    }

    private func startOfMonth(for date: Date, calendar: Calendar) -> Date {
        calendar.dateInterval(of: .month, for: date)!.start
    }

    private func startOfYear(for date: Date, calendar: Calendar) -> Date {
        calendar.dateInterval(of: .year, for: date)!.start
    }
}

// MARK: - Data Types

public struct DashboardData: Sendable {
    public let runningTimers: [RunningTimer]
    public let timeSummary: TimeSummary
    public let heatmap: HeatmapData
    public let sparkline: SparklineData
    public let projectDistribution: [ProjectDistributionEntry]
    public let peakHours: [Int: TimeInterval]
    public let stats: DashboardStats
}

public struct RunningTimer: Sendable {
    public let projectName: String
    public let duration: TimeInterval
}

public struct TimeSummary: Sendable {
    public let thisWeek: TimeInterval
    public let lastWeek: TimeInterval
    public let thisMonth: TimeInterval
    public let lastMonth: TimeInterval
    public let thisYear: TimeInterval

    public var weekDifference: TimeInterval { thisWeek - lastWeek }
    public var monthDifference: TimeInterval { thisMonth - lastMonth }
}

public struct HeatmapData: Sendable {
    public let weeks: [HeatmapWeek]
}

public struct HeatmapWeek: Sendable {
    public let weekStartDate: Date
    public let days: [DayActivity] // Always 7 entries, Mon-Sun
}

public struct DayActivity: Sendable {
    public let date: Date
    public let duration: TimeInterval
    public let isFuture: Bool
}

public struct SparklineData: Sendable {
    public let values: [SparklinePoint]
}

public struct SparklinePoint: Sendable {
    public let weekStartDate: Date
    public let value: TimeInterval
}

public struct ProjectDistributionEntry: Sendable {
    public let projectName: String
    public let duration: TimeInterval
    public let percentage: Double
    public let isRunning: Bool
}

public struct DashboardStats: Sendable {
    public let currentStreak: Int
    public let longestStreak: Int
    public let averageSessionDuration: TimeInterval
    public let longestSession: LongestSessionInfo?
    public let mostActiveWeekday: Int? // Calendar weekday: 1=Sun, 2=Mon, ..., 7=Sat
    public let dailyAvgWeek: TimeInterval
    public let sessionsThisWeek: Int
    public let totalHours: TimeInterval
    public let topProject: String?
    public let bestDayThisWeek: Int? // Calendar weekday
}

public struct LongestSessionInfo: Sendable {
    public let duration: TimeInterval
    public let projectName: String
    public let date: Date
}
