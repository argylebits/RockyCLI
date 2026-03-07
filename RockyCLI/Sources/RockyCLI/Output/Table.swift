import Foundation
import RockyCore

enum Table {
    static let divider: Character = "\u{2500}"
    static let activeIndicator = "\u{25B6}"
    static let inactiveIndicator = " "

    // MARK: - Status (no flags)

    static func renderStatus(_ statuses: [ProjectStatus]) -> String {
        guard !statuses.isEmpty else {
            return "No projects found."
        }

        let headers = ["Project", "Duration"]
        var rows: [Row] = []

        for status in statuses {
            let indicator = status.isRunning ? activeIndicator : inactiveIndicator
            let duration: String
            if let session = status.runningSession {
                duration = Formatter.duration(session.duration())
            } else {
                duration = "-"
            }
            rows.append(Row(indicator: indicator, cells: [status.project.name, duration]))
        }

        return renderTable(headers: headers, rows: rows)
    }

    // MARK: - Today totals

    static func renderTodayTotals(_ totals: ProjectTotals, period: String) -> String {
        var output = "Period:  \(period)\n\n"

        let headers = ["Project", "Total"]
        var rows: [Row] = []

        for entry in totals.entries {
            let indicator = entry.isRunning ? activeIndicator : inactiveIndicator
            rows.append(Row(indicator: indicator, cells: [entry.projectName, Formatter.duration(entry.duration)]))
        }

        let footer = Row(indicator: inactiveIndicator, cells: ["Total", Formatter.duration(totals.total)])
        output += renderTable(headers: headers, rows: rows, footerRows: [footer])
        return output
    }

    // MARK: - Grouped report

    static func renderGrouped(_ report: GroupedReport, period: String, projectFilter: String? = nil, hoursOnly: Bool = false) -> String {
        var output = ""
        if let project = projectFilter {
            output += "Project: \(project)\n"
        }
        output += "Period:  \(period)\n\n"

        if let projectFilter {
            // Single project — no Project column
            let headers = report.columns + ["Total"]

            if report.rows.isEmpty {
                output += "No time logged for \(projectFilter) in this period."
                return output
            }

            let row = report.rows[0]
            var cells: [String] = []
            for i in 0..<report.columns.count {
                let dur = row.columnDurations[i] ?? 0
                cells.append(dur > 0 ? Formatter.duration(dur, hoursOnly: hoursOnly) : "-")
            }
            cells.append(Formatter.duration(row.total, hoursOnly: hoursOnly))

            output += renderTable(headers: headers, rows: [Row(indicator: inactiveIndicator, cells: cells)], showIndicatorColumn: false)
        } else {
            let headers = ["Project"] + report.columns + ["Total"]
            var rows: [Row] = []

            for row in report.rows {
                let indicator = row.isRunning ? activeIndicator : inactiveIndicator
                var cells = [row.projectName]
                for i in 0..<report.columns.count {
                    let dur = row.columnDurations[i] ?? 0
                    cells.append(dur > 0 ? Formatter.duration(dur, hoursOnly: hoursOnly) : "-")
                }
                cells.append(Formatter.duration(row.total, hoursOnly: hoursOnly))
                rows.append(Row(indicator: indicator, cells: cells))
            }

            var totalCells = ["Total"]
            for i in 0..<report.columns.count {
                let dur = report.columnTotal(i)
                totalCells.append(dur > 0 ? Formatter.duration(dur, hoursOnly: hoursOnly) : "-")
            }
            totalCells.append(Formatter.duration(report.grandTotal, hoursOnly: hoursOnly))

            output += renderTable(headers: headers, rows: rows, footerRows: [Row(indicator: inactiveIndicator, cells: totalCells)])
        }

        return output
    }

    // MARK: - Verbose sessions

    static func renderVerbose(_ sessions: [VerboseSessionRow], period: String, projectFilter: String? = nil) -> String {
        var output = ""
        if let project = projectFilter {
            output += "Project: \(project)\n"
        }
        output += "Period:  \(period)\n\n"

        if sessions.isEmpty {
            output += "No sessions found in this period."
            return output
        }

        let now = Date()

        if projectFilter != nil {
            let headers = ["Date", "Start", "Stop", "Duration"]
            var rows: [Row] = []

            for row in sessions {
                let indicator = row.session.isRunning ? activeIndicator : inactiveIndicator
                let date = Formatter.dayOfWeek(row.session.startTime)
                let start = Formatter.time(row.session.startTime)
                let stop = row.session.isRunning ? "running" : Formatter.time(row.session.endTime!)
                let dur = Formatter.duration(row.session.duration(at: now))
                rows.append(Row(indicator: indicator, cells: [date, start, stop, dur]))
            }

            let total = sessions.reduce(0.0) { $0 + $1.session.duration(at: now) }
            let footer = Row(indicator: inactiveIndicator, cells: ["", "", "", Formatter.duration(total)])
            output += renderTable(headers: headers, rows: rows, footerRows: [footer])
        } else {
            let headers = ["Date", "Project", "Start", "Stop", "Duration"]
            var rows: [Row] = []

            for row in sessions {
                let indicator = row.session.isRunning ? activeIndicator : inactiveIndicator
                let date = Formatter.dayOfWeek(row.session.startTime)
                let start = Formatter.time(row.session.startTime)
                let stop = row.session.isRunning ? "running" : Formatter.time(row.session.endTime!)
                let dur = Formatter.duration(row.session.duration(at: now))
                rows.append(Row(indicator: indicator, cells: [date, row.projectName, start, stop, dur]))
            }

            let total = sessions.reduce(0.0) { $0 + $1.session.duration(at: now) }
            let footer = Row(indicator: inactiveIndicator, cells: ["", "", "", "", Formatter.duration(total)])
            output += renderTable(headers: headers, rows: rows, footerRows: [footer])
        }

        return output
    }

    // MARK: - Projects list

    static func renderProjects(_ projects: [Project]) -> String {
        let headers = ["Project", "Created"]
        let rows: [Row] = projects.map { project in
            Row(indicator: inactiveIndicator, cells: [project.name, Formatter.projectCreatedDate(project.createdAt)])
        }
        return renderTable(headers: headers, rows: rows)
    }

    // MARK: - Stop interactive prompt

    static func renderRunningTimers(_ sessions: [(Session, Project)]) -> String {
        let now = Date()
        var output = "Multiple timers running:\n\n"

        let headers = ["Project", "Duration"]
        var rows: [Row] = []

        for (i, (session, project)) in sessions.enumerated() {
            let dur = Formatter.duration(session.duration(at: now))
            rows.append(Row(indicator: inactiveIndicator, cells: ["\(i + 1). \(project.name)", dur]))
        }

        output += renderTable(headers: headers, rows: rows, indented: true)
        return output
    }

    // MARK: - Types

    private struct Row {
        let indicator: String
        let cells: [String]
    }

    // MARK: - Generic table renderer

    private static func renderTable(
        headers: [String]?,
        rows: [Row],
        footerRows: [Row] = [],
        showIndicatorColumn: Bool = true,
        indented: Bool = false
    ) -> String {
        let allCells: [[String]] = (headers.map { [$0] } ?? []) + rows.map(\.cells) + footerRows.map(\.cells)
        guard let first = allCells.first else { return "" }
        let columnCount = first.count

        var widths = [Int](repeating: 0, count: columnCount)
        for cells in allCells {
            for (i, cell) in cells.enumerated() where i < columnCount {
                widths[i] = max(widths[i], cell.count)
            }
        }

        var output = ""
        let indent = indented ? "    " : ""

        func formatRow(_ row: Row) -> String {
            var line = indent
            if showIndicatorColumn {
                line += row.indicator + " "
            }
            for (i, cell) in row.cells.enumerated() {
                if i > 0 { line += "   " }
                if i == 0 {
                    line += cell.padding(toLength: widths[i], withPad: " ", startingAt: 0)
                } else {
                    let padded = String(repeating: " ", count: max(0, widths[i] - cell.count)) + cell
                    line += padded
                }
            }
            return line.trimmingTrailingWhitespace()
        }

        func dividerLine() -> String {
            let indicatorWidth = showIndicatorColumn ? 3 : 0
            let indentWidth = indented ? 4 : 0
            let tableWidth = indentWidth + indicatorWidth + widths.reduce(0, +) + (columnCount - 1) * 3
            return String(repeating: divider, count: tableWidth)
        }

        if let headers {
            output += formatRow(Row(indicator: inactiveIndicator, cells: headers))
            output += "\n"
            output += dividerLine()
            output += "\n"
        }

        for row in rows {
            output += formatRow(row)
            output += "\n"
        }

        if !footerRows.isEmpty {
            output += dividerLine()
            output += "\n"
            for row in footerRows {
                output += formatRow(row)
                output += "\n"
            }
        }

        // Remove trailing newline
        if output.hasSuffix("\n") {
            output.removeLast()
        }

        return output
    }
}

extension String {
    func trimmingTrailingWhitespace() -> String {
        var s = self
        while s.last == " " {
            s.removeLast()
        }
        return s
    }
}
