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

    static func formatError(_ error: RockyError) -> String {
        return encode(["error": error])
    }

    static func formatJSON(_ result: CommandResult) -> String {
        switch result {
        case .sessionStarted(let session, _, _):
            return encode(["session": session])

        case .sessionStopped(let stopped):
            return encode(["sessions": stopped.map(\.session)])

        case .sessionStatus(let statuses):
            struct StatusOutput: Encodable { let sessions: [Session]; let projects: [Project] }
            let projects = statuses.map(\.project)
            let sessions = statuses.compactMap(\.runningSession)
            return encode(StatusOutput(sessions: sessions, projects: projects))

        case .sessionTodayTotals(_, _, let sessions):
            return encode(["sessions": sessions])

        case .sessionGrouped(_, _, _, _, let sessions):
            return encode(["sessions": sessions])

        case .sessionVerbose(let rows, _, _):
            return encode(["sessions": rows.map(\.session)])

        case .sessionEdited(let session):
            return encode(["session": session])

        case .sessionDeleted(let session, _):
            return encode(["session": session])

        case .projectList(let projects):
            return encode(["projects": projects])

        case .projectRenamed(_, let project):
            return encode(["project": project])

        case .projectDeleted(let project, let sessionCount):
            struct DeletedOutput: Encodable { let project: Project; let sessions_deleted: Int }
            return encode(DeletedOutput(project: project, sessions_deleted: sessionCount))

        case .dashboard:
            return encode(["message": formatText(result)])

        case .configValue(let key, let value):
            return encode(["key": key, "value": value])

        case .configList(let entries):
            return encode(["entries": entries.map { ["key": $0.key, "value": $0.value] }])

        case .message(let text):
            return encode(["message": text])
        }
    }

    private static func encode<T: Encodable>(_ value: T) -> String {
        let data = try! jsonEncoder.encode(value)
        return String(data: data, encoding: .utf8)!
    }


    // MARK: - Text

    static func formatText(_ result: CommandResult) -> String {
        switch result {
        case .sessionStarted(_, let project, let otherRunning):
            var msg = "Started \(project.name)"
            if !otherRunning.isEmpty {
                msg += "\nCurrently running: \(otherRunning.joined(separator: ", "))"
            }
            return msg

        case .sessionStopped(let stopped):
            if stopped.isEmpty {
                return "No timers currently running."
            }
            if stopped.count == 1 {
                let entry = stopped[0]
                return "Stopped \(entry.projectName) (\(DurationFormat.formatted(entry.session.duration())))"
            }
            let maxName = stopped.map(\.projectName.count).max() ?? 0
            return stopped.map { entry in
                let padded = entry.projectName.padding(toLength: maxName, withPad: " ", startingAt: 0)
                return "Stopped \(padded)  (\(DurationFormat.formatted(entry.session.duration())))"
            }.joined(separator: "\n")

        case .sessionStatus(let statuses):
            return Table.renderStatus(statuses)

        case .sessionTodayTotals(let totals, let period, _):
            return Table.renderTodayTotals(totals, period: period)

        case .sessionGrouped(let report, let period, let projectFilter, let hoursOnly, _):
            return Table.renderGrouped(report, period: period, projectFilter: projectFilter, hoursOnly: hoursOnly)

        case .sessionVerbose(let sessions, let period, let projectFilter):
            return Table.renderVerbose(sessions, period: period, projectFilter: projectFilter)

        case .sessionEdited(let session):
            let startStr = session.startTime.formatted(DateTimeFormat.time)
            let stopStr = session.isRunning ? "running" : session.endTime!.formatted(DateTimeFormat.time)
            let durStr = DurationFormat.formatted(session.duration())
            return "Updated: \(session.startTime.formatted(DateTimeFormat.dateWithDay))  \(startStr) — \(stopStr)  (\(durStr))"

        case .sessionDeleted(let session, let projectName):
            return "Deleted session \(session.id) (\(projectName), \(DurationFormat.formatted(session.duration())))"

        case .projectList(let projects):
            if projects.isEmpty {
                return "No projects found."
            }
            return Table.renderProjects(projects)

        case .projectRenamed(let oldName, let project):
            return "Renamed \(oldName) → \(project.name)"

        case .projectDeleted(let project, let sessionCount):
            return "Deleted project \(project.name) (\(sessionCount) sessions removed)"

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
