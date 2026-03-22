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

    @Test("stop with no running timers returns empty sessions")
    func stopNoRunning() throws {
        let (ctx, _, _) = buildCtx()

        let cmd = makeStop()
        let result = try cmd.execute(ctx: ctx)

        guard case .sessionStopped(let sessions, let projects) = result else {
            Issue.record("Expected .sessionStopped, got \(result)")
            return
        }
        #expect(sessions.isEmpty)
        #expect(projects.isEmpty)
    }

    @Test("stop single running timer returns stopped session")
    func stopSingleRunning() throws {
        let (ctx, projectRepo, sessionRepo) = buildCtx()

        let proj = try projectRepo.create(name: "acme-corp", slug: "acme-corp")
        _ = try sessionRepo.create(projectId: proj.id, startTime: Date().addingTimeInterval(-3600), endTime: nil)

        let cmd = makeStop()
        let result = try cmd.execute(ctx: ctx)

        let running = try sessionRepo.list(running: true)
        #expect(running.isEmpty)

        guard case .sessionStopped(let sessions, let projects) = result else {
            Issue.record("Expected .sessionStopped, got \(result)")
            return
        }
        #expect(sessions.count == 1)
        #expect(sessions[0].endTime != nil)
        #expect(!sessions[0].isRunning)
        #expect(projects.count == 1)
        #expect(projects[0].name == "acme-corp")
    }

    @Test("stop by project name stops only that project")
    func stopByProject() throws {
        let (ctx, projectRepo, sessionRepo) = buildCtx()

        let proj1 = try projectRepo.create(name: "project-a", slug: "project-a")
        let proj2 = try projectRepo.create(name: "project-b", slug: "project-b")
        _ = try sessionRepo.create(projectId: proj1.id, startTime: Date().addingTimeInterval(-3600), endTime: nil)
        _ = try sessionRepo.create(projectId: proj2.id, startTime: Date().addingTimeInterval(-1800), endTime: nil)

        let cmd = makeStop(project: "project-a")
        let result = try cmd.execute(ctx: ctx)

        let running = try sessionRepo.list(running: true)
        #expect(running.count == 1)
        #expect(running[0].1.name == "project-b")

        guard case .sessionStopped(let sessions, let projects) = result else {
            Issue.record("Expected .sessionStopped, got \(result)")
            return
        }
        #expect(sessions.count == 1)
        #expect(projects[0].name == "project-a")
    }

    @Test("stop --all stops all running timers and returns all sessions")
    func stopAll() throws {
        let (ctx, projectRepo, sessionRepo) = buildCtx()

        let proj1 = try projectRepo.create(name: "project-a", slug: "project-a")
        let proj2 = try projectRepo.create(name: "project-b", slug: "project-b")
        _ = try sessionRepo.create(projectId: proj1.id, startTime: Date().addingTimeInterval(-3600), endTime: nil)
        _ = try sessionRepo.create(projectId: proj2.id, startTime: Date().addingTimeInterval(-1800), endTime: nil)

        let cmd = makeStop(all: true)
        let result = try cmd.execute(ctx: ctx)

        let running = try sessionRepo.list(running: true)
        #expect(running.isEmpty)

        guard case .sessionStopped(let sessions, _) = result else {
            Issue.record("Expected .sessionStopped, got \(result)")
            return
        }
        #expect(sessions.count == 2)
        #expect(sessions.allSatisfy { !$0.isRunning })
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
        _ = try cmd.execute(ctx: ctx)

        let updated = try sessionRepo.get(id: session.id)
        #expect(updated != nil)
        #expect(updated!.endTime != nil)
        #expect(!updated!.isRunning)
    }

    @Test("stop --all with no running timers returns empty sessions")
    func stopAllNoRunning() throws {
        let (ctx, _, _) = buildCtx()

        let cmd = makeStop(all: true)
        let result = try cmd.execute(ctx: ctx)

        guard case .sessionStopped(let sessions, _) = result else {
            Issue.record("Expected .sessionStopped, got \(result)")
            return
        }
        #expect(sessions.isEmpty)
    }
}
