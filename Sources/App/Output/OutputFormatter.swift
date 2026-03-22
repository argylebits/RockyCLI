import Foundation
import RockyCore

enum OutputFormatter {

    static func formatText(_ result: CommandResult) -> String {
        switch result {
        case .started(let project, let running):
            var msg = "Started \(project)"
            if !running.isEmpty {
                msg += "\nCurrently running: \(running.joined(separator: ", "))"
            }
            return msg

        case .stopped(let entries):
            if entries.isEmpty {
                return "No timers currently running."
            }
            if entries.count == 1 {
                let e = entries[0]
                return "Stopped \(e.name) (\(DurationFormat.formatted(e.duration)))"
            }
            let maxName = entries.map(\.name.count).max() ?? 0
            return entries.map { entry in
                let padded = entry.name.padding(toLength: maxName, withPad: " ", startingAt: 0)
                return "Stopped \(padded)  (\(DurationFormat.formatted(entry.duration)))"
            }.joined(separator: "\n")

        case .status(let statuses):
            return Table.renderStatus(statuses)

        case .todayTotals(let totals, let period):
            return Table.renderTodayTotals(totals, period: period)

        case .grouped(let report, let period, let projectFilter, let hoursOnly):
            return Table.renderGrouped(report, period: period, projectFilter: projectFilter, hoursOnly: hoursOnly)

        case .verbose(let sessions, let period, let projectFilter):
            return Table.renderVerbose(sessions, period: period, projectFilter: projectFilter)

        case .edited(let session):
            let startStr = session.startTime.formatted(DateTimeFormat.time)
            let stopStr = session.isRunning ? "running" : session.endTime!.formatted(DateTimeFormat.time)
            let durStr = DurationFormat.formatted(session.duration())
            return "Updated: \(session.startTime.formatted(DateTimeFormat.dateWithDay))  \(startStr) — \(stopStr)  (\(durStr))"

        case .projectList(let projects):
            if projects.isEmpty {
                return "No projects found."
            }
            return Table.renderProjects(projects)

        case .projectRenamed(let oldName, let newName):
            return "Renamed \(oldName) → \(newName)"

        case .dashboard(let data):
            return DashboardRenderer.render(data)

        case .configValue(let key, let value):
            return "\(key) = \(value)"

        case .configList(let entries):
            if entries.isEmpty {
                return "No config values set. Defaults:\n  auto-stop = true"
            }
            return entries.map { "  \($0.key) = \($0.value)" }.joined(separator: "\n")

        case .message(let text):
            return text
        }
    }
}
