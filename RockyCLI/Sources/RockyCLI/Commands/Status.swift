import ArgumentParser
import Foundation
import RockyCore

struct Status: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Show time tracking summary."
    )

    @Flag(name: .long, help: "Show totals for today.")
    var today: Bool = false

    @Flag(name: .long, help: "Show totals by day for the current week.")
    var week: Bool = false

    @Flag(name: .long, help: "Show totals by week for the current month.")
    var month: Bool = false

    @Flag(name: .long, help: "Show totals by month for the current year.")
    var year: Bool = false

    @Option(name: .long, help: "Custom range start (YYYY-MM-DD).")
    var from: String?

    @Option(name: .long, help: "Custom range end (YYYY-MM-DD). Defaults to today.")
    var to: String?

    @Flag(name: .shortAndLong, help: "Show individual sessions with start/stop times.")
    var verbose: Bool = false

    @Option(name: .long, help: "Filter to a single project.")
    var project: String?

    func run() async throws {
        let db = try await Database.open()
        defer { Task { try? await db.close() } }

        let reportService = ReportService(db: db)
        let projectService = ProjectService(db: db)
        let calendar = Calendar.current

        // Resolve project filter
        var projectId: Int? = nil
        if let projectName = project {
            guard let proj = try await projectService.getByName(projectName) else {
                throw ValidationError("No project found with name \"\(projectName)\".")
            }
            projectId = proj.id
        }

        // No time range flags — show current status
        if !today && !week && !month && !year && from == nil {
            let statuses = try await reportService.allProjectsWithStatus()
            print(Table.renderStatus(statuses))
            return
        }

        let now = Date()

        if today {
            let (start, end) = dayRange(for: now, calendar: calendar)
            if verbose {
                let sessions = try await reportService.verboseSessions(from: start, to: end, projectId: projectId)
                print(Table.renderVerbose(sessions, period: Formatter.periodToday(), projectFilter: project))
            } else {
                let totals = try await reportService.totals(from: start, to: end, projectId: projectId)
                print(Table.renderTodayTotals(totals, period: Formatter.periodToday()))
            }
            return
        }

        if week {
            let (start, end) = weekRange(for: now, calendar: calendar)
            let period = Formatter.periodWeek(from: start, to: end)
            if verbose {
                let sessions = try await reportService.verboseSessions(from: start, to: end, projectId: projectId)
                print(Table.renderVerbose(sessions, period: period, projectFilter: project))
            } else {
                let report = try await reportService.groupedByDay(from: start, to: end, projectId: projectId)
                print(Table.renderGrouped(report, period: period, projectFilter: project))
            }
            return
        }

        if month {
            let (start, end) = monthRange(for: now, calendar: calendar)
            let period = Formatter.periodMonth(date: now)
            if verbose {
                let sessions = try await reportService.verboseSessions(from: start, to: end, projectId: projectId)
                print(Table.renderVerbose(sessions, period: period, projectFilter: project))
            } else {
                let report = try await reportService.groupedByWeekOfMonth(from: start, to: end, projectId: projectId)
                print(Table.renderGrouped(report, period: period, projectFilter: project))
            }
            return
        }

        if year {
            let (start, end) = yearRange(for: now, calendar: calendar)
            let period = Formatter.periodYear(date: now)
            if verbose {
                let sessions = try await reportService.verboseSessions(from: start, to: end, projectId: projectId)
                print(Table.renderVerbose(sessions, period: period, projectFilter: project))
            } else {
                let report = try await reportService.groupedByMonth(from: start, to: end, projectId: projectId)
                print(Table.renderGrouped(report, period: period, projectFilter: project, hoursOnly: true))
            }
            return
        }

        if let fromStr = from {
            guard let fromDate = parseDate(fromStr) else {
                throw ValidationError("Invalid date format: \(fromStr). Use YYYY-MM-DD.")
            }
            let toDate: Date
            if let toStr = to {
                guard let parsed = parseDate(toStr) else {
                    throw ValidationError("Invalid date format: \(toStr). Use YYYY-MM-DD.")
                }
                toDate = calendar.date(byAdding: .day, value: 1, to: parsed)!
            } else {
                let (_, endOfToday) = dayRange(for: now, calendar: calendar)
                toDate = endOfToday
            }

            let days = calendar.dateComponents([.day], from: fromDate, to: toDate).day ?? 0
            let period = Formatter.periodRange(from: fromDate, to: toDate)

            if verbose {
                let sessions = try await reportService.verboseSessions(from: fromDate, to: toDate, projectId: projectId)
                print(Table.renderVerbose(sessions, period: period, projectFilter: project))
            } else if days <= 7 {
                let report = try await reportService.groupedByDay(from: fromDate, to: toDate, projectId: projectId)
                print(Table.renderGrouped(report, period: period, projectFilter: project))
            } else if days <= 60 {
                let report = try await reportService.groupedByWeek(from: fromDate, to: toDate, projectId: projectId)
                print(Table.renderGrouped(report, period: period, projectFilter: project))
            } else {
                let report = try await reportService.groupedByMonth(from: fromDate, to: toDate, projectId: projectId)
                print(Table.renderGrouped(report, period: period, projectFilter: project, hoursOnly: true))
            }
        }
    }

    // MARK: - Date helpers

    private func parseDate(_ string: String) -> Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f.date(from: string)
    }

    private func dayRange(for date: Date, calendar: Calendar) -> (Date, Date) {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        return (start, end)
    }

    private func weekRange(for date: Date, calendar: Calendar) -> (Date, Date) {
        var cal = calendar
        cal.firstWeekday = 2 // Monday
        let interval = cal.dateInterval(of: .weekOfYear, for: date)!
        return (interval.start, interval.end)
    }

    private func monthRange(for date: Date, calendar: Calendar) -> (Date, Date) {
        let components = calendar.dateComponents([.year, .month], from: date)
        let start = calendar.date(from: components)!
        let end = calendar.date(byAdding: .month, value: 1, to: start)!
        return (start, end)
    }

    private func yearRange(for date: Date, calendar: Calendar) -> (Date, Date) {
        let components = calendar.dateComponents([.year], from: date)
        let start = calendar.date(from: components)!
        let end = calendar.date(byAdding: .year, value: 1, to: start)!
        return (start, end)
    }
}
