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

    // MARK: - Fallback cases

    @Test("sessionStarted falls back to text message in JSON")
    func sessionStartedFallback() throws {
        let result = CommandResult.sessionStarted(project: "Acme Corp", running: [])
        let json = OutputFormatter.formatJSON(result)
        assertValidJSON(json)
        let obj = try decode(json)
        #expect(obj["message"] as? String == "Started Acme Corp")
    }

    @Test("sessionStopped falls back to text message in JSON")
    func sessionStoppedFallback() throws {
        let result = CommandResult.sessionStopped(entries: [StopEntry(name: "Acme Corp", duration: 5400)])
        let json = OutputFormatter.formatJSON(result)
        assertValidJSON(json)
        let obj = try decode(json)
        #expect((obj["message"] as? String)?.contains("Stopped") == true)
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
