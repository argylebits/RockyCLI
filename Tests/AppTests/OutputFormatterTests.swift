import Foundation
import Testing
@testable import App
@testable import RockyCore

@Suite("OutputFormatter")
struct OutputFormatterTests {

    // MARK: - Started

    @Test("started formats project name")
    func startedBasic() {
        let project = Project(id: 1, parentId: nil, name: "Acme Corp", slug: "acme-corp", createdAt: Date())
        let session = Session(id: 1, projectId: 1, startTime: Date(), endTime: nil)
        let result = CommandResult.sessionStarted(session: session, project: project, otherRunning: [])
        let text = OutputFormatter.formatText(result)
        #expect(text == "Started Acme Corp")
    }

    @Test("started includes other running timers")
    func startedWithRunning() {
        let project = Project(id: 1, parentId: nil, name: "Acme Corp", slug: "acme-corp", createdAt: Date())
        let session = Session(id: 1, projectId: 1, startTime: Date(), endTime: nil)
        let result = CommandResult.sessionStarted(session: session, project: project, otherRunning: ["Project B", "Project C"])
        let text = OutputFormatter.formatText(result)
        #expect(text == "Started Acme Corp\nCurrently running: Project B, Project C")
    }

    // MARK: - Stopped

    @Test("stopped formats single entry")
    func stoppedSingle() {
        let session = Session(id: 1, projectId: 1, startTime: Date().addingTimeInterval(-9000), endTime: Date())
        let result = CommandResult.sessionStopped(stopped: [(session: session, projectName: "Acme Corp")])
        let text = OutputFormatter.formatText(result)
        #expect(text == "Stopped Acme Corp (2h 30m)")
    }

    @Test("stopped formats multiple entries with aligned names")
    func stoppedMultiple() {
        let s1 = Session(id: 1, projectId: 1, startTime: Date().addingTimeInterval(-9000), endTime: Date())
        let s2 = Session(id: 2, projectId: 2, startTime: Date().addingTimeInterval(-3600), endTime: Date())
        let result = CommandResult.sessionStopped(stopped: [
            (session: s1, projectName: "Acme Corp"),
            (session: s2, projectName: "Side"),
        ])
        let text = OutputFormatter.formatText(result)
        let lines = text.split(separator: "\n")
        #expect(lines.count == 2)
        #expect(lines[0].hasPrefix("Stopped Acme Corp"))
        #expect(lines[1].hasPrefix("Stopped Side"))
    }

    @Test("stopped with no running timers")
    func stoppedNoTimers() {
        let result = CommandResult.sessionStopped(stopped: [])
        let text = OutputFormatter.formatText(result)
        #expect(text == "No timers currently running.")
    }

    // MARK: - Status

    @Test("status delegates to Table.renderStatus")
    func status() {
        let project = Project(id: 1, parentId: nil, name: "Acme Corp", slug: "acme-corp", createdAt: Date())
        let statuses = [ProjectStatus(project: project, runningSession: nil)]
        let result = CommandResult.sessionStatus(statuses: statuses)
        let text = OutputFormatter.formatText(result)
        #expect(text == Table.renderStatus(statuses))
    }

    // MARK: - Today totals

    @Test("todayTotals delegates to Table.renderTodayTotals")
    func todayTotals() {
        let totals = ProjectTotals(entries: [])
        let period = "Saturday, March 22, 2026"
        let result = CommandResult.sessionTodayTotals(totals: totals, period: period, sessions: [])
        let text = OutputFormatter.formatText(result)
        #expect(text == Table.renderTodayTotals(totals, period: period))
    }

    // MARK: - Grouped

    @Test("grouped delegates to Table.renderGrouped")
    func grouped() {
        let report = GroupedReport(columns: ["Mon", "Tue"], rows: [])
        let result = CommandResult.sessionGrouped(report: report, period: "Mar 17 – Mar 22", projectFilter: nil, hoursOnly: false, sessions: [])
        let text = OutputFormatter.formatText(result)
        #expect(text == Table.renderGrouped(report, period: "Mar 17 – Mar 22"))
    }

    // MARK: - Verbose

    @Test("verbose delegates to Table.renderVerbose")
    func verbose() {
        let sessions: [VerboseSessionRow] = []
        let result = CommandResult.sessionVerbose(sessions: sessions, period: "Mar 22", projectFilter: nil)
        let text = OutputFormatter.formatText(result)
        #expect(text == Table.renderVerbose(sessions, period: "Mar 22"))
    }

    // MARK: - Edited

    @Test("edited formats session summary")
    func edited() {
        let start = Date().addingTimeInterval(-7200)
        let stop = Date().addingTimeInterval(-3600)
        let session = Session(id: 42, projectId: 1, startTime: start, endTime: stop)
        let result = CommandResult.sessionEdited(session: session)
        let text = OutputFormatter.formatText(result)
        let startStr = start.formatted(DateTimeFormat.time)
        let stopStr = stop.formatted(DateTimeFormat.time)
        let durStr = DurationFormat.formatted(session.duration())
        #expect(text == "Updated: \(start.formatted(DateTimeFormat.dateWithDay))  \(startStr) — \(stopStr)  (\(durStr))")
    }

    @Test("edited formats running session")
    func editedRunning() {
        let start = Date().addingTimeInterval(-3600)
        let session = Session(id: 42, projectId: 1, startTime: start, endTime: nil)
        let result = CommandResult.sessionEdited(session: session)
        let text = OutputFormatter.formatText(result)
        #expect(text.contains("running"))
    }

    // MARK: - Project list

    @Test("projectList delegates to Table.renderProjects")
    func projectList() {
        let projects = [
            Project(id: 1, parentId: nil, name: "Acme Corp", slug: "acme-corp", createdAt: Date()),
        ]
        let result = CommandResult.projectList(projects: projects)
        let text = OutputFormatter.formatText(result)
        #expect(text == Table.renderProjects(projects))
    }

    @Test("projectList with empty list")
    func projectListEmpty() {
        let result = CommandResult.projectList(projects: [])
        let text = OutputFormatter.formatText(result)
        #expect(text == "No projects found.")
    }

    // MARK: - Project renamed

    @Test("projectRenamed formats old and new names")
    func projectRenamed() {
        let project = Project(id: 1, parentId: nil, name: "Acme Inc", slug: "acme-inc", createdAt: Date())
        let result = CommandResult.projectRenamed(oldName: "acme-corp", project: project)
        let text = OutputFormatter.formatText(result)
        #expect(text == "Renamed acme-corp → Acme Inc")
    }

    // MARK: - Dashboard

    @Test("dashboard delegates to DashboardRenderer")
    func dashboard() {
        let data = DashboardData(
            runningTimers: [],
            timeSummary: TimeSummary(thisWeek: 0, lastWeek: 0, thisMonth: 0, lastMonth: 0, thisYear: 0),
            heatmap: HeatmapData(weeks: []),
            sparkline: SparklineData(values: []),
            projectDistribution: [],
            peakHours: [:],
            stats: DashboardStats(
                currentStreak: 0, longestStreak: 0, averageSessionDuration: 0,
                longestSession: nil, mostActiveWeekday: nil, dailyAvgWeek: 0,
                sessionsThisWeek: 0, totalHours: 0, topProject: nil, bestDayThisWeek: nil
            )
        )
        let result = CommandResult.dashboard(data: data)
        let text = OutputFormatter.formatText(result)
        #expect(text == DashboardRenderer.render(data))
    }

    // MARK: - Config

    @Test("configValue formats key-value pair")
    func configValue() {
        let result = CommandResult.configValue(key: "auto-stop", value: "true")
        let text = OutputFormatter.formatText(result)
        #expect(text == "auto-stop = true")
    }

    @Test("configList formats entries")
    func configList() {
        let result = CommandResult.configList(entries: [("auto-stop", "true"), ("theme", "dark")])
        let text = OutputFormatter.formatText(result)
        #expect(text == "  auto-stop = true\n  theme = dark")
    }

    @Test("configList with empty list shows defaults")
    func configListEmpty() {
        let result = CommandResult.configList(entries: [])
        let text = OutputFormatter.formatText(result)
        #expect(text == "No config values set. Defaults:\n  auto-stop = true")
    }

    // MARK: - Message

    @Test("message passes through")
    func message() {
        let result = CommandResult.message("No sessions found for Acme Corp.")
        let text = OutputFormatter.formatText(result)
        #expect(text == "No sessions found for Acme Corp.")
    }

    // MARK: - Error

    @Test("formatError includes code and message")
    func formatErrorWithAssociatedValue() throws {
        let error = RockyError.projectNotFound("acme-corp")
        let json = OutputFormatter.formatError(error)
        let data = json.data(using: .utf8)!
        let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let errorObj = obj["error"] as! [String: Any]
        #expect(errorObj["code"] as? String == "project_not_found")
        #expect(errorObj["message"] as? String == "Project not found: acme-corp")
    }

    @Test("formatError with plain case")
    func formatErrorPlainCase() throws {
        let error = RockyError.sessionOverdetermined
        let json = OutputFormatter.formatError(error)
        let data = json.data(using: .utf8)!
        let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let errorObj = obj["error"] as! [String: Any]
        #expect(errorObj["code"] as? String == "session_overdetermined")
        #expect(errorObj["message"] as? String == "Cannot specify --start, --stop, and --duration together.")
    }
}
