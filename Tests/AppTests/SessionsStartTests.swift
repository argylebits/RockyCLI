import Foundation
import Testing
@testable import App
@testable import RockyCore

@Suite("Sessions.Start Command")
struct SessionsStartTests {

    private func buildCtx(config: RockyConfig = .default) -> (AppContext, MockProjectRepository, MockSessionRepository) {
        let projectRepo = MockProjectRepository()
        let sessionRepo = MockSessionRepository(projectRepository: projectRepo)
        let ctx = AppContext(
            projectService: ProjectService(repository: projectRepo),
            sessionService: SessionService(repository: sessionRepo),
            reportService: ReportService(sessionRepository: sessionRepo, projectRepository: projectRepo),
            dashboardService: DashboardService(sessionRepository: sessionRepo, projectRepository: projectRepo),
            config: config
        )
        return (ctx, projectRepo, sessionRepo)
    }

    @Test("start creates project and returns started result")
    func startCreatesProject() throws {
        let (ctx, projectRepo, _) = buildCtx()

        var cmd = Sessions.Start()
        cmd.project = "acme-corp"
        let result = try cmd.execute(ctx: ctx)

        let projects = try projectRepo.list()
        #expect(projects.count == 1)
        #expect(projects[0].name == "acme-corp")

        guard case .sessionStarted(let session, let project, let otherRunning) = result else {
            Issue.record("Expected .sessionStarted, got \(result)")
            return
        }
        #expect(project.name == "acme-corp")
        #expect(session.isRunning)
        #expect(session.projectId == project.id)
        #expect(otherRunning.isEmpty)
    }

    @Test("start reuses existing project")
    func startReusesProject() throws {
        let (ctx, projectRepo, _) = buildCtx()

        _ = try projectRepo.create(name: "acme-corp", slug: "acme-corp")

        var cmd = Sessions.Start()
        cmd.project = "acme-corp"
        let result = try cmd.execute(ctx: ctx)

        let projects = try projectRepo.list()
        #expect(projects.count == 1)

        guard case .sessionStarted(_, let project, _) = result else {
            Issue.record("Expected .sessionStarted, got \(result)")
            return
        }
        #expect(project.name == "acme-corp")
    }

    @Test("start creates a running session")
    func startCreatesRunningSession() throws {
        let (ctx, _, sessionRepo) = buildCtx()

        var cmd = Sessions.Start()
        cmd.project = "acme-corp"
        _ = try cmd.execute(ctx: ctx)

        let running = try sessionRepo.list(running: true)
        #expect(running.count == 1)
        #expect(running[0].0.isRunning)
        #expect(running[0].1.name == "acme-corp")
    }

    @Test("start with auto-stop throws when timer already running for same project")
    func startAutoStopThrows() throws {
        let (ctx, projectRepo, sessionRepo) = buildCtx(config: RockyConfig(autoStop: true))

        let proj = try projectRepo.create(name: "acme-corp", slug: "acme-corp")
        _ = try sessionRepo.create(projectId: proj.id, startTime: Date(), endTime: nil)

        var cmd = Sessions.Start()
        cmd.project = "acme-corp"
        #expect(throws: RockyError.sessionTimerAlreadyRunning("acme-corp")) {
            try cmd.execute(ctx: ctx)
        }
    }

    @Test("start with auto-stop disabled allows duplicate timer for same project")
    func startAutoStopDisabled() throws {
        let (ctx, projectRepo, sessionRepo) = buildCtx(config: RockyConfig(autoStop: false))

        let proj = try projectRepo.create(name: "acme-corp", slug: "acme-corp")
        _ = try sessionRepo.create(projectId: proj.id, startTime: Date(), endTime: nil)

        var cmd = Sessions.Start()
        cmd.project = "acme-corp"
        _ = try cmd.execute(ctx: ctx)

        let running = try sessionRepo.list(running: true, projectId: proj.id)
        #expect(running.count == 2)
    }

    @Test("start allows timer for different project when one is already running")
    func startDifferentProject() throws {
        let (ctx, projectRepo, sessionRepo) = buildCtx()

        let proj1 = try projectRepo.create(name: "project-a", slug: "project-a")
        _ = try sessionRepo.create(projectId: proj1.id, startTime: Date(), endTime: nil)

        var cmd = Sessions.Start()
        cmd.project = "project-b"
        let result = try cmd.execute(ctx: ctx)

        let running = try sessionRepo.list(running: true)
        #expect(running.count == 2)

        guard case .sessionStarted(let session, let project, let otherRunning) = result else {
            Issue.record("Expected .sessionStarted, got \(result)")
            return
        }
        #expect(session.isRunning)
        #expect(project.name == "project-b")
        #expect(otherRunning.contains("project-a"))
    }
}
