import Foundation
import SQLiteNIO

public struct ReportService: Sendable {
    private let db: Database

    public init(db: Database) {
        self.db = db
    }

    // MARK: - Status (no flags)

    public func allProjectsWithStatus() async throws -> [ProjectStatus] {
        let rows = try await db.query("""
            SELECT p.*,
                   s.id AS s_id, s.start_time AS s_start_time, s.end_time AS s_end_time,
                   (SELECT MAX(s2.end_time) FROM sessions s2 WHERE s2.project_id = p.id) AS last_active
            FROM projects p
            LEFT JOIN sessions s ON s.project_id = p.id AND s.end_time IS NULL
            ORDER BY
                CASE WHEN s.id IS NOT NULL THEN 0 ELSE 1 END,
                s.start_time ASC,
                last_active DESC,
                p.created_at DESC
            """)

        var seen = Set<Int>()
        var results: [ProjectStatus] = []
        for row in rows {
            let project = try Project(row: row)
            if seen.contains(project.id) { continue }
            seen.insert(project.id)

            var runningSession: Session? = nil
            if let sId = row.column("s_id")?.integer,
               let sStartStr = row.column("s_start_time")?.string {
                runningSession = Session(
                    id: sId,
                    projectId: project.id,
                    startTime: try DateFormatter.sqlite.parseOrThrow(sStartStr),
                    endTime: nil
                )
            }
            results.append(ProjectStatus(project: project, runningSession: runningSession))
        }
        return results
    }

    // MARK: - Time range reports

    public func totals(from: Date, to: Date, projectId: Int? = nil) async throws -> ProjectTotals {
        let sessionService = SessionService(db: db)
        let sessions = try await sessionService.getSessions(from: from, to: to, projectId: projectId)
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

    public func groupedByMonth(from: Date, to: Date, projectId: Int? = nil) async throws -> GroupedReport {
        try await grouped(from: from, to: to, projectId: projectId, grouping: .month)
    }

    private func grouped(from: Date, to: Date, projectId: Int? = nil, grouping: Grouping) async throws -> GroupedReport {
        let sessionService = SessionService(db: db)
        let sessions = try await sessionService.getSessions(from: from, to: to, projectId: projectId)
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
        let sessionService = SessionService(db: db)
        let sessions = try await sessionService.getSessions(from: from, to: to, projectId: projectId)

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
                let next = calendar.date(byAdding: .day, value: 7, to: current)!
                let end = min(next, to)
                columns.append(Column(label: "Week \(weekNum)", start: current, end: end))
                current = next
                weekNum += 1
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
}

private enum Grouping {
    case day, week, month
}

private struct Column {
    let label: String
    let start: Date
    let end: Date
}
