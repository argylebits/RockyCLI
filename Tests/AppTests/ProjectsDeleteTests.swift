import Foundation
import Testing
@testable import App
@testable import RockyCore

@Suite("Projects.Delete Command")
struct ProjectsDeleteTests {

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

    @Test("delete by name with confirm removes project and sessions")
    func deleteByNameWithConfirm() throws {
        let (ctx, projectRepo, sessionRepo) = buildCtx()
        let proj = try projectRepo.create(name: "acme-corp", slug: "acme-corp")
        _ = try sessionRepo.create(projectId: proj.id, startTime: Date().addingTimeInterval(-3600), endTime: Date())
        _ = try sessionRepo.create(projectId: proj.id, startTime: Date().addingTimeInterval(-1800), endTime: Date())

        var cmd = Projects.Delete()
        cmd.name = "acme-corp"
        cmd.confirm = true
        let result = try cmd.execute(ctx: ctx)

        guard case .projectDeleted(let project, let sessionCount) = result else {
            Issue.record("Expected .projectDeleted, got \(result)")
            return
        }
        #expect(project.name == "acme-corp")
        #expect(sessionCount == 2)
        #expect(try projectRepo.get(id: proj.id) == nil)
    }

    @Test("delete removes all associated sessions")
    func deleteRemovesSessions() throws {
        let (ctx, projectRepo, sessionRepo) = buildCtx()
        let proj = try projectRepo.create(name: "acme-corp", slug: "acme-corp")
        let s1 = try sessionRepo.create(projectId: proj.id, startTime: Date().addingTimeInterval(-3600), endTime: Date())
        let s2 = try sessionRepo.create(projectId: proj.id, startTime: Date().addingTimeInterval(-1800), endTime: Date())

        var cmd = Projects.Delete()
        cmd.name = "acme-corp"
        cmd.confirm = true
        _ = try cmd.execute(ctx: ctx)

        #expect(try sessionRepo.get(id: s1.id) == nil)
        #expect(try sessionRepo.get(id: s2.id) == nil)
    }

    @Test("delete does not affect other projects")
    func deleteDoesNotAffectOthers() throws {
        let (ctx, projectRepo, sessionRepo) = buildCtx()
        let proj1 = try projectRepo.create(name: "project-a", slug: "project-a")
        let proj2 = try projectRepo.create(name: "project-b", slug: "project-b")
        _ = try sessionRepo.create(projectId: proj1.id, startTime: Date().addingTimeInterval(-3600), endTime: Date())
        let s2 = try sessionRepo.create(projectId: proj2.id, startTime: Date().addingTimeInterval(-1800), endTime: Date())

        var cmd = Projects.Delete()
        cmd.name = "project-a"
        cmd.confirm = true
        _ = try cmd.execute(ctx: ctx)

        #expect(try projectRepo.get(id: proj2.id) != nil)
        #expect(try sessionRepo.get(id: s2.id) != nil)
    }

    @Test("delete throws for unknown project")
    func deleteUnknownProject() throws {
        let (ctx, _, _) = buildCtx()

        var cmd = Projects.Delete()
        cmd.name = "nonexistent"
        cmd.confirm = true
        #expect(throws: RockyError.projectNotFound("nonexistent")) {
            try cmd.execute(ctx: ctx)
        }
    }

    @Test("delete project with no sessions returns zero count")
    func deleteProjectNoSessions() throws {
        let (ctx, projectRepo, _) = buildCtx()
        _ = try projectRepo.create(name: "empty", slug: "empty")

        var cmd = Projects.Delete()
        cmd.name = "empty"
        cmd.confirm = true
        let result = try cmd.execute(ctx: ctx)

        guard case .projectDeleted(_, let sessionCount) = result else {
            Issue.record("Expected .projectDeleted, got \(result)")
            return
        }
        #expect(sessionCount == 0)
    }

    // MARK: - Parsing

    @Test("rocky projects delete parses name argument")
    func parsesName() throws {
        let cmd = try Rocky.parseAsRoot(["projects", "delete", "acme-corp"])
        #expect(cmd is Projects.Delete)
        let del = cmd as! Projects.Delete
        #expect(del.name == "acme-corp")
    }

    @Test("rocky projects delete parses with no arguments")
    func parsesNoArgs() throws {
        let cmd = try Rocky.parseAsRoot(["projects", "delete"])
        #expect(cmd is Projects.Delete)
        let del = cmd as! Projects.Delete
        #expect(del.name == nil)
    }

    @Test("rocky projects delete parses --confirm flag")
    func parsesConfirm() throws {
        let cmd = try Rocky.parseAsRoot(["projects", "delete", "acme-corp", "--confirm"])
        let del = cmd as! Projects.Delete
        #expect(del.confirm == true)
    }

    @Test("rocky projects delete parses --output json")
    func parsesOutputJson() throws {
        let cmd = try Rocky.parseAsRoot(["projects", "delete", "acme-corp", "--output", "json"])
        let del = cmd as! Projects.Delete
        #expect(del.outputOptions.output == .json)
    }
}
