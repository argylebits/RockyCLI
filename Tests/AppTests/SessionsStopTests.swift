import Foundation
import Testing
@testable import App
@testable import RockyCore

@Suite("Sessions.Stop Command")
struct SessionsStopTests {

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

    private func makeStop(project: String? = nil, all: Bool = false) -> Sessions.Stop {
        var cmd = Sessions.Stop()
        cmd.project = project
        cmd.all = all
        return cmd
    }

    @Test("stop with no running timers does not throw")
    func stopNoRunning() throws {
        let (ctx, _, _) = buildCtx()

        let cmd = makeStop()
        try cmd.execute(ctx: ctx)
    }

    @Test("stop single running timer stops it")
    func stopSingleRunning() throws {
        let (ctx, projectRepo, sessionRepo) = buildCtx()

        let proj = try projectRepo.create(name: "acme-corp", slug: "acme-corp")
        _ = try sessionRepo.create(projectId: proj.id, startTime: Date().addingTimeInterval(-3600), endTime: nil)

        let cmd = makeStop()
        try cmd.execute(ctx: ctx)

        let running = try sessionRepo.list(running: true)
        #expect(running.isEmpty)
    }

    @Test("stop by project name stops only that project")
    func stopByProject() throws {
        let (ctx, projectRepo, sessionRepo) = buildCtx()

        let proj1 = try projectRepo.create(name: "project-a", slug: "project-a")
        let proj2 = try projectRepo.create(name: "project-b", slug: "project-b")
        _ = try sessionRepo.create(projectId: proj1.id, startTime: Date().addingTimeInterval(-3600), endTime: nil)
        _ = try sessionRepo.create(projectId: proj2.id, startTime: Date().addingTimeInterval(-1800), endTime: nil)

        let cmd = makeStop(project: "project-a")
        try cmd.execute(ctx: ctx)

        let running = try sessionRepo.list(running: true)
        #expect(running.count == 1)
        #expect(running[0].1.name == "project-b")
    }

    @Test("stop --all stops all running timers")
    func stopAll() throws {
        let (ctx, projectRepo, sessionRepo) = buildCtx()

        let proj1 = try projectRepo.create(name: "project-a", slug: "project-a")
        let proj2 = try projectRepo.create(name: "project-b", slug: "project-b")
        _ = try sessionRepo.create(projectId: proj1.id, startTime: Date().addingTimeInterval(-3600), endTime: nil)
        _ = try sessionRepo.create(projectId: proj2.id, startTime: Date().addingTimeInterval(-1800), endTime: nil)

        let cmd = makeStop(all: true)
        try cmd.execute(ctx: ctx)

        let running = try sessionRepo.list(running: true)
        #expect(running.isEmpty)
    }

    @Test("stop by project name throws when project not found")
    func stopProjectNotFound() throws {
        let (ctx, _, _) = buildCtx()

        let cmd = makeStop(project: "nonexistent")
        #expect(throws: RockyError.projectNotFound("nonexistent")) {
            try cmd.execute(ctx: ctx)
        }
    }

    @Test("stop by project name throws when no timer running for project")
    func stopProjectNotRunning() throws {
        let (ctx, projectRepo, _) = buildCtx()

        _ = try projectRepo.create(name: "acme-corp", slug: "acme-corp")

        let cmd = makeStop(project: "acme-corp")
        #expect(throws: RockyError.sessionNoTimerRunning("acme-corp")) {
            try cmd.execute(ctx: ctx)
        }
    }

    @Test("stop sets endTime on the session")
    func stopSetsEndTime() throws {
        let (ctx, projectRepo, sessionRepo) = buildCtx()

        let proj = try projectRepo.create(name: "acme-corp", slug: "acme-corp")
        let session = try sessionRepo.create(projectId: proj.id, startTime: Date().addingTimeInterval(-3600), endTime: nil)

        let cmd = makeStop()
        try cmd.execute(ctx: ctx)

        let updated = try sessionRepo.get(id: session.id)
        #expect(updated != nil)
        #expect(updated!.endTime != nil)
        #expect(!updated!.isRunning)
    }

    @Test("stop --all with no running timers does not throw")
    func stopAllNoRunning() throws {
        let (ctx, _, _) = buildCtx()

        let cmd = makeStop(all: true)
        try cmd.execute(ctx: ctx)
    }
}
