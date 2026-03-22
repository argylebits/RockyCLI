import Foundation
import RockyCore

enum OutputFormatter {

    // MARK: - JSON

    private static let jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    static func formatJSON(_ result: CommandResult) -> String {
        switch result {
        case .sessionEdited(let session):
            return encode(["session": session])

        case .sessionStatus(let statuses):
            let projects = statuses.map(\.project)
            let sessions = statuses.compactMap(\.runningSession)
            return encode(SessionsWithProjects(sessions: sessions, projects: projects))

        case .sessionVerbose(let rows, _, _):
            return encode(["sessions": rows.map(\.session)])

        case .projectList(let projects):
            return encode(["projects": projects])

        case .configValue(let key, let value):
            return encode(["key": key, "value": value])

        case .configList(let entries):
            return encode(["entries": entries.map { ["key": $0.key, "value": $0.value] }])

        case .message(let text):
            return encode(["message": text])

        default:
            // sessionStarted, sessionStopped, sessionTodayTotals, sessionGrouped,
            // projectRenamed, dashboard — these don't carry full models yet.
            // They will be reworked when commands are migrated to return models (#126).
            return encode(["message": formatText(result)])
        }
    }

    private static func encode<T: Encodable>(_ value: T) -> String {
        let data = try! jsonEncoder.encode(value)
        return String(data: data, encoding: .utf8)!
    }


    // MARK: - Text

    static func formatText(_ result: CommandResult) -> String {
        switch result {
        case .sessionStarted(let project, let running):
            var msg = "Started \(project)"
            if !running.isEmpty {
                msg += "\nCurrently running: \(running.joined(separator: ", "))"
            }
            return msg

        case .sessionStopped(let entries):
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

        case .sessionStatus(let statuses):
            return Table.renderStatus(statuses)

        case .sessionTodayTotals(let totals, let period):
            return Table.renderTodayTotals(totals, period: period)

        case .sessionGrouped(let report, let period, let projectFilter, let hoursOnly):
            return Table.renderGrouped(report, period: period, projectFilter: projectFilter, hoursOnly: hoursOnly)

        case .sessionVerbose(let sessions, let period, let projectFilter):
            return Table.renderVerbose(sessions, period: period, projectFilter: projectFilter)

        case .sessionEdited(let session):
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
