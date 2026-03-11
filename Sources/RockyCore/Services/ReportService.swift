import Foundation

public struct ReportService: Sendable {
    private let sessionRepository: any SessionRepository
    private let projectRepository: any ProjectRepository

    public init(sessionRepository: any SessionRepository, projectRepository: any ProjectRepository) {
        self.sessionRepository = sessionRepository
        self.projectRepository = projectRepository
    }

    // MARK: - Status (no flags)

    public func allProjectsWithStatus() async throws -> [ProjectStatus] {
        let projects = try await projectRepository.list()
        let runningSessions = try await sessionRepository.getRunningWithProjects()

        let runningByProjectId = Dictionary(
            runningSessions.map { ($0.0.projectId, $0.0) },
            uniquingKeysWith: { first, _ in first }
        )

        var running: [ProjectStatus] = []
        var idle: [ProjectStatus] = []

        for project in projects {
            if let session = runningByProjectId[project.id] {
                running.append(ProjectStatus(project: project, runningSession: session))
            } else {
                idle.append(ProjectStatus(project: project, runningSession: nil))
            }
        }

        return running + idle
    }

    // MARK: - Time range reports

    public func totals(from: Date, to: Date, projectId: Int? = nil) async throws -> ProjectTotals {
        let sessions = try await sessionRepository.getSessions(from: from, to: to, projectId: projectId)
        let now = Date()

        var projectDurations: [String: TimeInterval] = [:]
        var projectRunning: [String: Bool] = [:]

        for (session, project) in sessions {
            let clampedStart = max(session.startTime, from)
            let clampedEnd = min(session.endTime ?? now, to)
            let duration = max(0, clampedEnd.timeIntervalSince(clampedStart))

            projectDurations[project.name, default: 0] += duration
            if session.isRunning {
                projectRunning[project.name] = true
            }
        }

        let entries = projectDurations.map { name, duration in
            ProjectTotalEntry(
                projectName: name,
                duration: duration,
                isRunning: projectRunning[name] ?? false
            )
        }.sorted { a, b in
            if a.isRunning != b.isRunning { return a.isRunning }
            return a.duration > b.duration
        }

        return ProjectTotals(entries: entries)
    }

    public func groupedByDay(from: Date, to: Date, projectId: Int? = nil) async throws -> GroupedReport {
        try await grouped(from: from, to: to, projectId: projectId, grouping: .day)
    }

    public func groupedByWeek(from: Date, to: Date, projectId: Int? = nil) async throws -> GroupedReport {
        try await grouped(from: from, to: to, projectId: projectId, grouping: .week)
    }

    public func groupedByWeekOfMonth(from: Date, to: Date, projectId: Int? = nil) async throws -> GroupedReport {
        try await grouped(from: from, to: to, projectId: projectId, grouping: .weekOfMonth)
    }

    public func groupedByMonth(from: Date, to: Date, projectId: Int? = nil) async throws -> GroupedReport {
        try await grouped(from: from, to: to, projectId: projectId, grouping: .month)
    }

    private func grouped(from: Date, to: Date, projectId: Int? = nil, grouping: Grouping) async throws -> GroupedReport {
        let sessions = try await sessionRepository.getSessions(from: from, to: to, projectId: projectId)
        let now = Date()
        let calendar = Calendar.current

        let columns = generateColumns(from: from, to: to, grouping: grouping, calendar: calendar)

        // project name -> column index -> duration
        var data: [String: [Int: TimeInterval]] = [:]
        var projectRunning: [String: Bool] = [:]

        for (session, project) in sessions {
            let clampedStart = max(session.startTime, from)
            let clampedEnd = min(session.endTime ?? now, to)

            if session.isRunning {
                projectRunning[project.name] = true
            }

            // Distribute duration across columns
            for (i, column) in columns.enumerated() {
                let overlapStart = max(clampedStart, column.start)
                let overlapEnd = min(clampedEnd, column.end)
                if overlapEnd > overlapStart {
                    let duration = overlapEnd.timeIntervalSince(overlapStart)
                    data[project.name, default: [:]][i, default: 0] += duration
                }
            }
        }

        let rows = data.map { name, columnDurations in
            GroupedReportRow(
                projectName: name,
                isRunning: projectRunning[name] ?? false,
                columnDurations: columnDurations
            )
        }.sorted { a, b in
            if a.isRunning != b.isRunning { return a.isRunning }
            let aTotal = a.columnDurations.values.reduce(0, +)
            let bTotal = b.columnDurations.values.reduce(0, +)
            return aTotal > bTotal
        }

        return GroupedReport(columns: columns.map(\.label), rows: rows)
    }

    public func verboseSessions(from: Date, to: Date, projectId: Int? = nil) async throws -> [VerboseSessionRow] {
        let sessions = try await sessionRepository.getSessions(from: from, to: to, projectId: projectId)

        return sessions.map { session, project in
            VerboseSessionRow(
                session: session,
                projectName: project.name
            )
        }
    }

    // MARK: - Column generation

    private func generateColumns(from: Date, to: Date, grouping: Grouping, calendar: Calendar) -> [Column] {
        var columns: [Column] = []
        var current = from

        switch grouping {
        case .day:
            while current < to {
                let next = calendar.date(byAdding: .day, value: 1, to: current)!
                let end = min(next, to)
                let dayName = dayFormatter.string(from: current)
                columns.append(Column(label: dayName, start: current, end: end))
                current = next
            }
        case .week:
            var weekNum = 1
            while current < to {
                guard let interval = calendar.dateInterval(of: .weekOfYear, for: current) else { break }
                let start = max(interval.start, from)
                let end = min(interval.end, to)
                columns.append(Column(label: "Week \(weekNum)", start: start, end: end))
                current = interval.end
                weekNum += 1
            }
        case .weekOfMonth:
            var seen = Set<Int>()
            while current < to {
                let weekNum = calendar.component(.weekOfMonth, from: current)
                guard let interval = calendar.dateInterval(of: .weekOfMonth, for: current) else { break }
                if !seen.contains(weekNum) {
                    seen.insert(weekNum)
                    let start = max(interval.start, from)
                    let end = min(interval.end, to)
                    columns.append(Column(label: "Week \(weekNum)", start: start, end: end))
                }
                current = interval.end
            }
        case .month:
            while current < to {
                let next = calendar.date(byAdding: .month, value: 1, to: current)!
                let end = min(next, to)
                let monthName = monthFormatter.string(from: current)
                columns.append(Column(label: monthName, start: current, end: end))
                current = next
            }
        }
        return columns
    }

    private var dayFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f
    }

    private var monthFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f
    }
}

// MARK: - Types

public struct ProjectStatus: Sendable {
    public let project: Project
    public let runningSession: Session?

    public var isRunning: Bool { runningSession != nil }
}

public struct ProjectTotals: Sendable {
    public let entries: [ProjectTotalEntry]

    public var total: TimeInterval {
        entries.reduce(0) { $0 + $1.duration }
    }
}

public struct ProjectTotalEntry: Sendable {
    public let projectName: String
    public let duration: TimeInterval
    public let isRunning: Bool
}

public struct GroupedReport: Sendable {
    public let columns: [String]
    public let rows: [GroupedReportRow]

    public func columnTotal(_ index: Int) -> TimeInterval {
        rows.reduce(0) { $0 + ($1.columnDurations[index] ?? 0) }
    }

    public var grandTotal: TimeInterval {
        rows.reduce(0) { total, row in
            total + row.columnDurations.values.reduce(0, +)
        }
    }
}

public struct GroupedReportRow: Sendable {
    public let projectName: String
    public let isRunning: Bool
    public let columnDurations: [Int: TimeInterval]

    public var total: TimeInterval {
        columnDurations.values.reduce(0, +)
    }
}

public struct VerboseSessionRow: Sendable {
    public let session: Session
    public let projectName: String

    public init(session: Session, projectName: String) {
        self.session = session
        self.projectName = projectName
    }
}

private enum Grouping {
    case day, week, weekOfMonth, month
}

private struct Column {
    let label: String
    let start: Date
    let end: Date
}
