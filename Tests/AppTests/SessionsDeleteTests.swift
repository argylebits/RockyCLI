import Foundation
import Testing
@testable import App
@testable import RockyCore

@Suite("Sessions.Delete Command")
struct SessionsDeleteTests {

    private func buildCtx() -> (AppContext, MockProjectRepository, MockSessionRepository) {
        let projectRepo = MockProjectRepository()
        let sessionRepo = MockSessionRepository(projectRepository: projectRepo)
        let ctx = AppContext(
            projectService: ProjectService(repository: projectRepo),
            sessionService: SessionService(repository: sessionRepo),
            reportService: ReportService(sessionRepository: sessionRepo, projectRepository: projectRepo),
            dashboardService: DashboardService(sessionRepository: sessionRepo, projectRepository: projectRepo)
        )
        return (ctx, projectRepo, sessionRepo)
    }

    @Test("delete by id removes session and returns result")
    func deleteById() throws {
        let (ctx, projectRepo, sessionRepo) = buildCtx()
        let proj = try projectRepo.create(name: "acme-corp", slug: "acme-corp")
        let session = try sessionRepo.create(projectId: proj.id, startTime: Date().addingTimeInterval(-3600), endTime: Date())

        var cmd = Sessions.Delete()
        cmd.id = session.id
        let result = try cmd.execute(ctx: ctx)

        guard case .sessionDeleted(let deleted, let projectName) = result else {
            Issue.record("Expected .sessionDeleted, got \(result)")
            return
        }
        #expect(deleted.id == session.id)
        #expect(projectName == "acme-corp")
        #expect(try sessionRepo.get(id: session.id) == nil)
    }

    @Test("delete running session succeeds")
    func deleteRunningSession() throws {
        let (ctx, projectRepo, sessionRepo) = buildCtx()
        let proj = try projectRepo.create(name: "acme-corp", slug: "acme-corp")
        let session = try sessionRepo.create(projectId: proj.id, startTime: Date().addingTimeInterval(-3600), endTime: nil)

        var cmd = Sessions.Delete()
        cmd.id = session.id
        let result = try cmd.execute(ctx: ctx)

        guard case .sessionDeleted(let deleted, _) = result else {
            Issue.record("Expected .sessionDeleted, got \(result)")
            return
        }
        #expect(deleted.id == session.id)
        #expect(try sessionRepo.get(id: session.id) == nil)
    }

    @Test("delete throws for unknown id")
    func deleteUnknownId() throws {
        let (ctx, _, _) = buildCtx()

        var cmd = Sessions.Delete()
        cmd.id = 999
        #expect(throws: RockyError.sessionNotFound(999)) {
            try cmd.execute(ctx: ctx)
        }
    }

    @Test("delete error formats as structured JSON")
    func deleteErrorJSON() throws {
        let error = RockyError.sessionNotFound(999)
        let json = OutputFormatter.formatError(error)
        let data = json.data(using: .utf8)!
        let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let errorObj = obj["error"] as! [String: Any]
        #expect(errorObj["code"] as? String == "session_not_found")
    }

    // MARK: - Parsing

    @Test("rocky sessions delete parses id argument")
    func parsesId() throws {
        let cmd = try Rocky.parseAsRoot(["sessions", "delete", "41"])
        #expect(cmd is Sessions.Delete)
        let del = cmd as! Sessions.Delete
        #expect(del.id == 41)
    }

    @Test("rocky sessions delete parses with no arguments")
    func parsesNoArgs() throws {
        let cmd = try Rocky.parseAsRoot(["sessions", "delete"])
        #expect(cmd is Sessions.Delete)
        let del = cmd as! Sessions.Delete
        #expect(del.id == nil)
    }

    @Test("rocky sessions delete parses --output json")
    func parsesOutputJson() throws {
        let cmd = try Rocky.parseAsRoot(["sessions", "delete", "41", "--output", "json"])
        let del = cmd as! Sessions.Delete
        #expect(del.outputOptions.output == .json)
    }
}
