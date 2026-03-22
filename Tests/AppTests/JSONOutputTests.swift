import Foundation
import Testing
@testable import App
@testable import RockyCore

@Suite("JSON Output")
struct JSONOutputTests {

    // MARK: - Helpers

    private func decode(_ json: String) throws -> [String: Any] {
        let data = json.data(using: .utf8)!
        return try JSONSerialization.jsonObject(with: data) as! [String: Any]
    }

    private func assertValidJSON(_ json: String, file: String = #file, line: Int = #line) {
        let data = json.data(using: .utf8)!
        #expect(throws: Never.self) {
            _ = try JSONSerialization.jsonObject(with: data)
        }
    }

    // MARK: - Session Started

    @Test("sessionStarted JSON has command and data fields")
    func sessionStarted() throws {
        let result = CommandResult.sessionStarted(project: "Acme Corp", running: ["Side Project"])
        let json = OutputFormatter.formatJSON(result)
        assertValidJSON(json)
        let obj = try decode(json)
        #expect(obj["command"] as? String == "session.start")
        let data = obj["data"] as! [String: Any]
        #expect(data["project"] as? String == "Acme Corp")
        #expect(data["running"] as? [String] == ["Side Project"])
    }

    @Test("sessionStarted JSON with no running timers")
    func sessionStartedNoRunning() throws {
        let result = CommandResult.sessionStarted(project: "Acme Corp", running: [])
        let json = OutputFormatter.formatJSON(result)
        let obj = try decode(json)
        let data = obj["data"] as! [String: Any]
        #expect(data["running"] as? [String] == [])
    }

    // MARK: - Session Stopped

    @Test("sessionStopped JSON includes session entries")
    func sessionStopped() throws {
        let result = CommandResult.sessionStopped(entries: [
            StopEntry(name: "Acme Corp", duration: 9000),
            StopEntry(name: "Side Project", duration: 2700),
        ])
        let json = OutputFormatter.formatJSON(result)
        assertValidJSON(json)
        let obj = try decode(json)
        #expect(obj["command"] as? String == "session.stop")
        let data = obj["data"] as! [String: Any]
        let sessions = data["sessions"] as! [[String: Any]]
        #expect(sessions.count == 2)
        #expect(sessions[0]["project"] as? String == "Acme Corp")
        #expect(sessions[0]["duration"] as? Int == 9000)
        #expect(sessions[1]["project"] as? String == "Side Project")
        #expect(sessions[1]["duration"] as? Int == 2700)
    }

    @Test("sessionStopped JSON with empty entries")
    func sessionStoppedEmpty() throws {
        let result = CommandResult.sessionStopped(entries: [])
        let json = OutputFormatter.formatJSON(result)
        let obj = try decode(json)
        let data = obj["data"] as! [String: Any]
        let sessions = data["sessions"] as! [[String: Any]]
        #expect(sessions.isEmpty)
    }

    // MARK: - Session Status

    @Test("sessionStatus JSON includes project statuses")
    func sessionStatus() throws {
        let project = Project(id: 1, parentId: nil, name: "Acme Corp", slug: "acme-corp", createdAt: Date())
        let session = Session(id: 5, projectId: 1, startTime: Date().addingTimeInterval(-3600), endTime: nil)
        let statuses = [ProjectStatus(project: project, runningSession: session)]
        let result = CommandResult.sessionStatus(statuses: statuses)
        let json = OutputFormatter.formatJSON(result)
        assertValidJSON(json)
        let obj = try decode(json)
        #expect(obj["command"] as? String == "session.status")
        let data = obj["data"] as! [String: Any]
        let projects = data["projects"] as! [[String: Any]]
        #expect(projects.count == 1)
        #expect(projects[0]["project"] as? String == "Acme Corp")
        #expect(projects[0]["running"] as? Bool == true)
    }

    // MARK: - Session Today Totals

    @Test("sessionTodayTotals JSON includes entries and total")
    func sessionTodayTotals() throws {
        let totals = ProjectTotals(entries: [
            ProjectTotalEntry(projectName: "Acme Corp", duration: 5400, isRunning: true),
        ])
        let result = CommandResult.sessionTodayTotals(totals: totals, period: "Saturday, March 22, 2026")
        let json = OutputFormatter.formatJSON(result)
        assertValidJSON(json)
        let obj = try decode(json)
        #expect(obj["command"] as? String == "session.today")
        let data = obj["data"] as! [String: Any]
        #expect(data["period"] as? String == "Saturday, March 22, 2026")
        #expect(data["total"] as? Int == 5400)
        let entries = data["entries"] as! [[String: Any]]
        #expect(entries[0]["project"] as? String == "Acme Corp")
        #expect(entries[0]["duration"] as? Int == 5400)
        #expect(entries[0]["running"] as? Bool == true)
    }

    // MARK: - Session Grouped

    @Test("sessionGrouped JSON includes columns and rows")
    func sessionGrouped() throws {
        let report = GroupedReport(columns: ["Mon", "Tue"], rows: [
            GroupedReportRow(projectName: "Acme Corp", isRunning: false, columnDurations: [0: 7200, 1: 3600]),
        ])
        let result = CommandResult.sessionGrouped(report: report, period: "Mar 17 – Mar 22", projectFilter: nil, hoursOnly: false)
        let json = OutputFormatter.formatJSON(result)
        assertValidJSON(json)
        let obj = try decode(json)
        #expect(obj["command"] as? String == "session.grouped")
        let data = obj["data"] as! [String: Any]
        #expect(data["columns"] as? [String] == ["Mon", "Tue"])
        #expect(data["period"] as? String == "Mar 17 – Mar 22")
        let rows = data["rows"] as! [[String: Any]]
        #expect(rows[0]["project"] as? String == "Acme Corp")
    }

    // MARK: - Session Verbose

    @Test("sessionVerbose JSON includes session details")
    func sessionVerbose() throws {
        let start = Date().addingTimeInterval(-3600)
        let stop = Date()
        let session = Session(id: 7, projectId: 1, startTime: start, endTime: stop)
        let sessions = [VerboseSessionRow(session: session, projectName: "Acme Corp")]
        let result = CommandResult.sessionVerbose(sessions: sessions, period: "Mar 22", projectFilter: nil)
        let json = OutputFormatter.formatJSON(result)
        assertValidJSON(json)
        let obj = try decode(json)
        #expect(obj["command"] as? String == "session.verbose")
        let data = obj["data"] as! [String: Any]
        let jsonSessions = data["sessions"] as! [[String: Any]]
        #expect(jsonSessions[0]["id"] as? Int == 7)
        #expect(jsonSessions[0]["project"] as? String == "Acme Corp")
        #expect(jsonSessions[0]["running"] as? Bool == false)
    }

    // MARK: - Session Edited

    @Test("sessionEdited JSON includes session data")
    func sessionEdited() throws {
        let start = Date().addingTimeInterval(-7200)
        let stop = Date().addingTimeInterval(-3600)
        let session = Session(id: 42, projectId: 1, startTime: start, endTime: stop)
        let result = CommandResult.sessionEdited(session: session)
        let json = OutputFormatter.formatJSON(result)
        assertValidJSON(json)
        let obj = try decode(json)
        #expect(obj["command"] as? String == "session.edit")
        let data = obj["data"] as! [String: Any]
        #expect(data["id"] as? Int == 42)
        #expect(data["duration"] as? Int == 3600)
        #expect(data["running"] as? Bool == false)
    }

    // MARK: - Project List

    @Test("projectList JSON includes projects")
    func projectList() throws {
        let projects = [
            Project(id: 1, parentId: nil, name: "Acme Corp", slug: "acme-corp", createdAt: Date()),
        ]
        let result = CommandResult.projectList(projects: projects)
        let json = OutputFormatter.formatJSON(result)
        assertValidJSON(json)
        let obj = try decode(json)
        #expect(obj["command"] as? String == "project.list")
        let data = obj["data"] as! [String: Any]
        let jsonProjects = data["projects"] as! [[String: Any]]
        #expect(jsonProjects[0]["name"] as? String == "Acme Corp")
        #expect(jsonProjects[0]["slug"] as? String == "acme-corp")
    }

    // MARK: - Project Renamed

    @Test("projectRenamed JSON includes old and new names")
    func projectRenamed() throws {
        let result = CommandResult.projectRenamed(oldName: "acme-corp", newName: "Acme Inc")
        let json = OutputFormatter.formatJSON(result)
        assertValidJSON(json)
        let obj = try decode(json)
        #expect(obj["command"] as? String == "project.rename")
        let data = obj["data"] as! [String: Any]
        #expect(data["oldName"] as? String == "acme-corp")
        #expect(data["newName"] as? String == "Acme Inc")
    }

    // MARK: - Dashboard

    @Test("dashboard JSON is valid")
    func dashboard() throws {
        let data = DashboardData(
            runningTimers: [RunningTimer(projectName: "Acme Corp", duration: 3600)],
            timeSummary: TimeSummary(thisWeek: 36000, lastWeek: 32000, thisMonth: 140000, lastMonth: 145000, thisYear: 500000),
            heatmap: HeatmapData(weeks: []),
            sparkline: SparklineData(values: []),
            projectDistribution: [],
            peakHours: [:],
            stats: DashboardStats(
                currentStreak: 5, longestStreak: 12, averageSessionDuration: 5160,
                longestSession: nil, mostActiveWeekday: nil, dailyAvgWeek: 7200,
                sessionsThisWeek: 9, totalHours: 500000, topProject: "Acme Corp", bestDayThisWeek: nil
            )
        )
        let result = CommandResult.dashboard(data: data)
        let json = OutputFormatter.formatJSON(result)
        assertValidJSON(json)
        let obj = try decode(json)
        #expect(obj["command"] as? String == "dashboard")
    }

    // MARK: - Config

    @Test("configValue JSON has key and value")
    func configValue() throws {
        let result = CommandResult.configValue(key: "auto-stop", value: "true")
        let json = OutputFormatter.formatJSON(result)
        assertValidJSON(json)
        let obj = try decode(json)
        #expect(obj["command"] as? String == "config.get")
        let data = obj["data"] as! [String: Any]
        #expect(data["key"] as? String == "auto-stop")
        #expect(data["value"] as? String == "true")
    }

    @Test("configList JSON has entries")
    func configList() throws {
        let result = CommandResult.configList(entries: [("auto-stop", "true")])
        let json = OutputFormatter.formatJSON(result)
        assertValidJSON(json)
        let obj = try decode(json)
        #expect(obj["command"] as? String == "config.list")
        let data = obj["data"] as! [String: Any]
        let entries = data["entries"] as! [[String: Any]]
        #expect(entries[0]["key"] as? String == "auto-stop")
        #expect(entries[0]["value"] as? String == "true")
    }

    // MARK: - Message

    @Test("message JSON has message field")
    func message() throws {
        let result = CommandResult.message("No sessions found for Acme Corp.")
        let json = OutputFormatter.formatJSON(result)
        assertValidJSON(json)
        let obj = try decode(json)
        #expect(obj["command"] as? String == "message")
        let data = obj["data"] as! [String: Any]
        #expect(data["message"] as? String == "No sessions found for Acme Corp.")
    }

    // MARK: - Envelope structure

    @Test("all JSON has command and data keys at top level")
    func envelopeStructure() throws {
        let result = CommandResult.sessionStarted(project: "Test", running: [])
        let json = OutputFormatter.formatJSON(result)
        let obj = try decode(json)
        #expect(obj.keys.contains("command"))
        #expect(obj.keys.contains("data"))
        #expect(obj.keys.count == 2)
    }
}
