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

    private func assertValidJSON(_ json: String) {
        let data = json.data(using: .utf8)!
        #expect(throws: Never.self) {
            _ = try JSONSerialization.jsonObject(with: data)
        }
    }

    // MARK: - Session Edited

    @Test("sessionEdited returns the session model")
    func sessionEdited() throws {
        let start = Date().addingTimeInterval(-7200)
        let stop = Date().addingTimeInterval(-3600)
        let session = Session(id: 42, projectId: 1, startTime: start, endTime: stop)
        let result = CommandResult.sessionEdited(session: session)
        let json = OutputFormatter.formatJSON(result)
        assertValidJSON(json)
        let obj = try decode(json)
        let sessionJSON = obj["session"] as! [String: Any]
        #expect(sessionJSON["id"] as? Int == 42)
        #expect(sessionJSON["project_id"] as? Int == 1)
        #expect(sessionJSON["start_time"] as? String != nil)
        #expect(sessionJSON["end_time"] as? String != nil)
    }

    // MARK: - Session Status

    @Test("sessionStatus returns sessions and projects")
    func sessionStatus() throws {
        let project = Project(id: 1, parentId: nil, name: "Acme Corp", slug: "acme-corp", createdAt: Date())
        let session = Session(id: 5, projectId: 1, startTime: Date().addingTimeInterval(-3600), endTime: nil)
        let statuses = [ProjectStatus(project: project, runningSession: session)]
        let result = CommandResult.sessionStatus(statuses: statuses)
        let json = OutputFormatter.formatJSON(result)
        assertValidJSON(json)
        let obj = try decode(json)
        let sessions = obj["sessions"] as! [[String: Any]]
        #expect(sessions.count == 1)
        #expect(sessions[0]["id"] as? Int == 5)
        #expect(sessions[0]["end_time"] == nil)
        let projects = obj["projects"] as! [[String: Any]]
        #expect(projects.count == 1)
        #expect(projects[0]["name"] as? String == "Acme Corp")
        #expect(projects[0]["slug"] as? String == "acme-corp")
    }

    @Test("sessionStatus with no running sessions returns empty sessions array")
    func sessionStatusNoRunning() throws {
        let project = Project(id: 1, parentId: nil, name: "Acme Corp", slug: "acme-corp", createdAt: Date())
        let statuses = [ProjectStatus(project: project, runningSession: nil)]
        let result = CommandResult.sessionStatus(statuses: statuses)
        let json = OutputFormatter.formatJSON(result)
        let obj = try decode(json)
        let sessions = obj["sessions"] as! [[String: Any]]
        #expect(sessions.isEmpty)
        let projects = obj["projects"] as! [[String: Any]]
        #expect(projects.count == 1)
    }

    // MARK: - Session Verbose

    @Test("sessionVerbose returns session models")
    func sessionVerbose() throws {
        let start = Date().addingTimeInterval(-3600)
        let stop = Date()
        let session = Session(id: 7, projectId: 1, startTime: start, endTime: stop)
        let rows = [VerboseSessionRow(session: session, projectName: "Acme Corp")]
        let result = CommandResult.sessionVerbose(sessions: rows, period: "Mar 22", projectFilter: nil)
        let json = OutputFormatter.formatJSON(result)
        assertValidJSON(json)
        let obj = try decode(json)
        let sessions = obj["sessions"] as! [[String: Any]]
        #expect(sessions.count == 1)
        #expect(sessions[0]["id"] as? Int == 7)
        #expect(sessions[0]["project_id"] as? Int == 1)
        #expect(sessions[0]["start_time"] as? String != nil)
        #expect(sessions[0]["end_time"] as? String != nil)
    }

    // MARK: - Project List

    @Test("projectList returns project models")
    func projectList() throws {
        let projects = [
            Project(id: 1, parentId: nil, name: "Acme Corp", slug: "acme-corp", createdAt: Date()),
        ]
        let result = CommandResult.projectList(projects: projects)
        let json = OutputFormatter.formatJSON(result)
        assertValidJSON(json)
        let obj = try decode(json)
        let jsonProjects = obj["projects"] as! [[String: Any]]
        #expect(jsonProjects.count == 1)
        #expect(jsonProjects[0]["name"] as? String == "Acme Corp")
        #expect(jsonProjects[0]["slug"] as? String == "acme-corp")
        #expect(jsonProjects[0]["id"] as? Int == 1)
        #expect(jsonProjects[0]["created_at"] as? String != nil)
    }

    // MARK: - Config

    @Test("configValue returns key and value")
    func configValue() throws {
        let result = CommandResult.configValue(key: "auto-stop", value: "true")
        let json = OutputFormatter.formatJSON(result)
        assertValidJSON(json)
        let obj = try decode(json)
        #expect(obj["key"] as? String == "auto-stop")
        #expect(obj["value"] as? String == "true")
    }

    @Test("configList returns entries")
    func configList() throws {
        let result = CommandResult.configList(entries: [("auto-stop", "true")])
        let json = OutputFormatter.formatJSON(result)
        assertValidJSON(json)
        let obj = try decode(json)
        let entries = obj["entries"] as! [[String: Any]]
        #expect(entries[0]["key"] as? String == "auto-stop")
        #expect(entries[0]["value"] as? String == "true")
    }

    // MARK: - Message

    @Test("message returns message field")
    func message() throws {
        let result = CommandResult.message("No sessions found.")
        let json = OutputFormatter.formatJSON(result)
        assertValidJSON(json)
        let obj = try decode(json)
        #expect(obj["message"] as? String == "No sessions found.")
    }

    // MARK: - Session Started

    @Test("sessionStarted returns session model")
    func sessionStarted() throws {
        let project = Project(id: 1, parentId: nil, name: "Acme Corp", slug: "acme-corp", createdAt: Date())
        let session = Session(id: 10, projectId: 1, startTime: Date(), endTime: nil)
        let result = CommandResult.sessionStarted(session: session, project: project, otherRunning: [])
        let json = OutputFormatter.formatJSON(result)
        assertValidJSON(json)
        let obj = try decode(json)
        let sessionJSON = obj["session"] as! [String: Any]
        #expect(sessionJSON["id"] as? Int == 10)
        #expect(sessionJSON["project_id"] as? Int == 1)
        #expect(sessionJSON["end_time"] == nil)
    }

    // MARK: - Session Stopped

    @Test("sessionStopped returns session models")
    func sessionStopped() throws {
        let session = Session(id: 5, projectId: 1, startTime: Date().addingTimeInterval(-3600), endTime: Date())
        let result = CommandResult.sessionStopped(stopped: [(session: session, projectName: "Acme Corp")])
        let json = OutputFormatter.formatJSON(result)
        assertValidJSON(json)
        let obj = try decode(json)
        let sessions = obj["sessions"] as! [[String: Any]]
        #expect(sessions.count == 1)
        #expect(sessions[0]["id"] as? Int == 5)
        #expect(sessions[0]["end_time"] as? String != nil)
        #expect(sessions[0]["project_id"] as? Int == 1)
    }

    // MARK: - Project Renamed

    @Test("projectRenamed returns project model")
    func projectRenamed() throws {
        let project = Project(id: 1, parentId: nil, name: "New Name", slug: "new-name", createdAt: Date())
        let result = CommandResult.projectRenamed(oldName: "old-name", project: project)
        let json = OutputFormatter.formatJSON(result)
        assertValidJSON(json)
        let obj = try decode(json)
        let projectJSON = obj["project"] as! [String: Any]
        #expect(projectJSON["name"] as? String == "New Name")
        #expect(projectJSON["slug"] as? String == "new-name")
    }

    // MARK: - Error

    @Test("formatError returns error envelope with code and message")
    func formatError() throws {
        let error = RockyError.sessionNoTimerRunning("Acme Corp")
        let json = OutputFormatter.formatError(error)
        assertValidJSON(json)
        let obj = try decode(json)
        let errorObj = obj["error"] as! [String: Any]
        #expect(errorObj["code"] as? String == "session_no_timer_running")
        #expect(errorObj["message"] as? String == "No timer running for Acme Corp.")
    }

    // MARK: - Dates are ISO8601

    @Test("dates encode as ISO8601 strings")
    func datesAreISO8601() throws {
        let session = Session(id: 1, projectId: 1, startTime: Date(), endTime: Date())
        let result = CommandResult.sessionEdited(session: session)
        let json = OutputFormatter.formatJSON(result)
        let obj = try decode(json)
        let sessionJSON = obj["session"] as! [String: Any]
        let startTime = sessionJSON["start_time"] as! String
        #expect(startTime.contains("T"))
        #expect(startTime.hasSuffix("Z"))
    }
}
