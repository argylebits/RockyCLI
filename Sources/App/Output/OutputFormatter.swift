import Foundation
import RockyCore

enum OutputFormatter {

    // MARK: - JSON

    static func formatJSON(_ result: CommandResult) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        switch result {
        case .sessionStarted(let project, let running):
            return encode(encoder, command: "session.start",
                          data: SessionStartJSON(project: project, running: running))

        case .sessionStopped(let entries):
            return encode(encoder, command: "session.stop",
                          data: SessionStopJSON(sessions: entries.map {
                              SessionStopEntryJSON(project: $0.name, duration: Int($0.duration))
                          }))

        case .sessionStatus(let statuses):
            return encode(encoder, command: "session.status",
                          data: SessionStatusJSON(projects: statuses.map { status in
                              SessionStatusEntryJSON(
                                  project: status.project.name,
                                  slug: status.project.slug,
                                  running: status.isRunning,
                                  duration: status.runningSession.map { Int($0.duration()) },
                                  startTime: status.runningSession?.startTime.iso8601String
                              )
                          }))

        case .sessionTodayTotals(let totals, let period):
            return encode(encoder, command: "session.today",
                          data: SessionTodayJSON(
                              period: period,
                              total: Int(totals.total),
                              entries: totals.entries.map {
                                  SessionTotalEntryJSON(project: $0.projectName, duration: Int($0.duration), running: $0.isRunning)
                              }
                          ))

        case .sessionGrouped(let report, let period, let projectFilter, _):
            return encode(encoder, command: "session.grouped",
                          data: SessionGroupedJSON(
                              period: period,
                              columns: report.columns,
                              rows: report.rows.map { row in
                                  var durations: [String: Int] = [:]
                                  for (i, col) in report.columns.enumerated() {
                                      durations[col] = Int(row.columnDurations[i] ?? 0)
                                  }
                                  return SessionGroupedRowJSON(
                                      project: row.projectName,
                                      running: row.isRunning,
                                      total: Int(row.total),
                                      durations: durations
                                  )
                              },
                              grandTotal: Int(report.grandTotal),
                              projectFilter: projectFilter
                          ))

        case .sessionVerbose(let sessions, let period, let projectFilter):
            return encode(encoder, command: "session.verbose",
                          data: SessionVerboseJSON(
                              period: period,
                              sessions: sessions.map { row in
                                  SessionVerboseEntryJSON(
                                      id: row.session.id,
                                      project: row.projectName,
                                      startTime: row.session.startTime.iso8601String,
                                      endTime: row.session.endTime?.iso8601String,
                                      duration: Int(row.session.duration()),
                                      running: row.session.isRunning
                                  )
                              },
                              total: Int(sessions.reduce(0.0) { $0 + $1.session.duration() }),
                              projectFilter: projectFilter
                          ))

        case .sessionEdited(let session):
            return encode(encoder, command: "session.edit",
                          data: SessionEditedJSON(
                              id: session.id,
                              startTime: session.startTime.iso8601String,
                              endTime: session.endTime?.iso8601String,
                              duration: Int(session.duration()),
                              running: session.isRunning
                          ))

        case .projectList(let projects):
            return encode(encoder, command: "project.list",
                          data: ProjectListJSON(projects: projects.map {
                              ProjectJSON(id: $0.id, name: $0.name, slug: $0.slug, createdAt: $0.createdAt.iso8601String)
                          }))

        case .projectRenamed(let oldName, let newName):
            return encode(encoder, command: "project.rename",
                          data: ProjectRenameJSON(oldName: oldName, newName: newName))

        case .dashboard(let dashboardData):
            return encode(encoder, command: "dashboard",
                          data: DashboardJSON(
                              runningTimers: dashboardData.runningTimers.map {
                                  DashboardRunningTimerJSON(project: $0.projectName, duration: Int($0.duration))
                              },
                              timeSummary: DashboardTimeSummaryJSON(
                                  thisWeek: Int(dashboardData.timeSummary.thisWeek),
                                  lastWeek: Int(dashboardData.timeSummary.lastWeek),
                                  thisMonth: Int(dashboardData.timeSummary.thisMonth),
                                  lastMonth: Int(dashboardData.timeSummary.lastMonth),
                                  thisYear: Int(dashboardData.timeSummary.thisYear)
                              ),
                              stats: DashboardStatsJSON(
                                  currentStreak: dashboardData.stats.currentStreak,
                                  longestStreak: dashboardData.stats.longestStreak,
                                  sessionsThisWeek: dashboardData.stats.sessionsThisWeek,
                                  averageSessionDuration: Int(dashboardData.stats.averageSessionDuration),
                                  dailyAvgWeek: Int(dashboardData.stats.dailyAvgWeek),
                                  totalHours: Int(dashboardData.stats.totalHours)
                              )
                          ))

        case .configValue(let key, let value):
            return encode(encoder, command: "config.get",
                          data: ConfigValueJSON(key: key, value: value))

        case .configList(let entries):
            return encode(encoder, command: "config.list",
                          data: ConfigListJSON(entries: entries.map {
                              ConfigValueJSON(key: $0.key, value: $0.value)
                          }))

        case .message(let text):
            return encode(encoder, command: "message",
                          data: MessageJSON(message: text))
        }
    }

    private static func encode<T: Encodable>(_ encoder: JSONEncoder, command: String, data: T) -> String {
        let envelope = JSONEnvelope(command: command, data: data)
        let jsonData = try! encoder.encode(envelope)
        return String(data: jsonData, encoding: .utf8)!
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
