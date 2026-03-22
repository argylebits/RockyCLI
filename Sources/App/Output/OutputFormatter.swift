import Foundation
import RockyCore

enum OutputFormatter {

    // MARK: - JSON

    static func formatJSON(_ result: CommandResult) -> String {
        let (command, data) = jsonPayload(result)
        let envelope: [String: Any] = ["command": command, "data": data]
        return encodeJSON(envelope)
    }

    private static func jsonPayload(_ result: CommandResult) -> (command: String, data: [String: Any]) {
        switch result {
        case .sessionStarted(let project, let running):
            return ("session.start", [
                "project": project,
                "running": running,
            ])

        case .sessionStopped(let entries):
            return ("session.stop", [
                "sessions": entries.map { entry in
                    ["project": entry.name, "duration": Int(entry.duration)] as [String: Any]
                },
            ])

        case .sessionStatus(let statuses):
            return ("session.status", [
                "projects": statuses.map { status in
                    var dict: [String: Any] = [
                        "project": status.project.name,
                        "slug": status.project.slug,
                        "running": status.isRunning,
                    ]
                    if let session = status.runningSession {
                        dict["duration"] = Int(session.duration())
                        dict["startTime"] = session.startTime.iso8601String
                    }
                    return dict
                },
            ])

        case .sessionTodayTotals(let totals, let period):
            return ("session.today", [
                "period": period,
                "total": Int(totals.total),
                "entries": totals.entries.map { entry in
                    [
                        "project": entry.projectName,
                        "duration": Int(entry.duration),
                        "running": entry.isRunning,
                    ] as [String: Any]
                },
            ])

        case .sessionGrouped(let report, let period, let projectFilter, _):
            var data: [String: Any] = [
                "period": period,
                "columns": report.columns,
                "rows": report.rows.map { row in
                    var dict: [String: Any] = [
                        "project": row.projectName,
                        "running": row.isRunning,
                        "total": Int(row.total),
                    ]
                    var durations: [String: Int] = [:]
                    for (i, col) in report.columns.enumerated() {
                        durations[col] = Int(row.columnDurations[i] ?? 0)
                    }
                    dict["durations"] = durations
                    return dict
                },
                "grandTotal": Int(report.grandTotal),
            ]
            if let filter = projectFilter {
                data["projectFilter"] = filter
            }
            return ("session.grouped", data)

        case .sessionVerbose(let sessions, let period, let projectFilter):
            var data: [String: Any] = [
                "period": period,
                "sessions": sessions.map { row in
                    var dict: [String: Any] = [
                        "id": row.session.id,
                        "project": row.projectName,
                        "startTime": row.session.startTime.iso8601String,
                        "duration": Int(row.session.duration()),
                        "running": row.session.isRunning,
                    ]
                    if let endTime = row.session.endTime {
                        dict["endTime"] = endTime.iso8601String
                    }
                    return dict
                },
                "total": Int(sessions.reduce(0.0) { $0 + $1.session.duration() }),
            ]
            if let filter = projectFilter {
                data["projectFilter"] = filter
            }
            return ("session.verbose", data)

        case .sessionEdited(let session):
            var data: [String: Any] = [
                "id": session.id,
                "startTime": session.startTime.iso8601String,
                "duration": Int(session.duration()),
                "running": session.isRunning,
            ]
            if let endTime = session.endTime {
                data["endTime"] = endTime.iso8601String
            }
            return ("session.edit", data)

        case .projectList(let projects):
            return ("project.list", [
                "projects": projects.map { project in
                    [
                        "id": project.id,
                        "name": project.name,
                        "slug": project.slug,
                        "createdAt": project.createdAt.iso8601String,
                    ] as [String: Any]
                },
            ])

        case .projectRenamed(let oldName, let newName):
            return ("project.rename", [
                "oldName": oldName,
                "newName": newName,
            ])

        case .dashboard(let data):
            return ("dashboard", [
                "runningTimers": data.runningTimers.map { timer in
                    ["project": timer.projectName, "duration": Int(timer.duration)] as [String: Any]
                },
                "timeSummary": [
                    "thisWeek": Int(data.timeSummary.thisWeek),
                    "lastWeek": Int(data.timeSummary.lastWeek),
                    "thisMonth": Int(data.timeSummary.thisMonth),
                    "lastMonth": Int(data.timeSummary.lastMonth),
                    "thisYear": Int(data.timeSummary.thisYear),
                ] as [String: Any],
                "stats": [
                    "currentStreak": data.stats.currentStreak,
                    "longestStreak": data.stats.longestStreak,
                    "sessionsThisWeek": data.stats.sessionsThisWeek,
                    "averageSessionDuration": Int(data.stats.averageSessionDuration),
                    "dailyAvgWeek": Int(data.stats.dailyAvgWeek),
                    "totalHours": Int(data.stats.totalHours),
                ] as [String: Any],
            ])

        case .configValue(let key, let value):
            return ("config.get", [
                "key": key,
                "value": value,
            ])

        case .configList(let entries):
            return ("config.list", [
                "entries": entries.map { ["key": $0.key, "value": $0.value] },
            ])

        case .message(let text):
            return ("message", [
                "message": text,
            ])
        }
    }

    private static func encodeJSON(_ dict: [String: Any]) -> String {
        let data = try! JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys])
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
