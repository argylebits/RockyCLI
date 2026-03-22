import Foundation
import Testing
@testable import App
@testable import RockyCore

private let editDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd HH:mm"
    f.timeZone = .current
    return f
}()

@Suite("Sessions.Edit Command")
struct SessionsEditTests {

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

    private func makeEdit(
        project: String? = nil,
        session: Int? = nil,
        start: String? = nil,
        stop: String? = nil,
        duration: Double? = nil
    ) -> Sessions.Edit {
        var cmd = Sessions.Edit()
        cmd.project = project
        cmd.session = session
        cmd.start = start
        cmd.stop = stop
        cmd.duration = duration
        return cmd
    }

    // MARK: - Flag resolution

    @Test("edit with --start only updates start, keeps stop")
    func editStartOnly() throws {
        let (ctx, projectRepo, sessionRepo) = buildCtx()
        let proj = try projectRepo.create(name: "acme-corp", slug: "acme-corp")
        let originalStart = Date().addingTimeInterval(-7200)
        let originalStop = Date().addingTimeInterval(-3600)
        let session = try sessionRepo.create(projectId: proj.id, startTime: originalStart, endTime: originalStop)

        let newStart = Date().addingTimeInterval(-5400)
        let cmd = makeEdit(session: session.id, start: editDateFormatter.string(from:newStart))
        try cmd.execute(ctx: ctx)

        let updated = try sessionRepo.get(id: session.id)!
        #expect(abs(updated.startTime.timeIntervalSince(newStart)) < 60)
        #expect(abs(updated.endTime!.timeIntervalSince(originalStop)) < 1)
    }

    @Test("edit with --stop only updates stop, keeps start")
    func editStopOnly() throws {
        let (ctx, projectRepo, sessionRepo) = buildCtx()
        let proj = try projectRepo.create(name: "acme-corp", slug: "acme-corp")
        let originalStart = Date().addingTimeInterval(-7200)
        let originalStop = Date().addingTimeInterval(-3600)
        let session = try sessionRepo.create(projectId: proj.id, startTime: originalStart, endTime: originalStop)

        let newStop = Date().addingTimeInterval(-1800)
        let cmd = makeEdit(session: session.id, stop: editDateFormatter.string(from:newStop))
        try cmd.execute(ctx: ctx)

        let updated = try sessionRepo.get(id: session.id)!
        #expect(abs(updated.startTime.timeIntervalSince(originalStart)) < 1)
        #expect(abs(updated.endTime!.timeIntervalSince(newStop)) < 60)
    }

    @Test("edit with --start and --stop updates both")
    func editStartAndStop() throws {
        let (ctx, projectRepo, sessionRepo) = buildCtx()
        let proj = try projectRepo.create(name: "acme-corp", slug: "acme-corp")
        let session = try sessionRepo.create(projectId: proj.id,
                                             startTime: Date().addingTimeInterval(-7200),
                                             endTime: Date().addingTimeInterval(-3600))

        let newStart = Date().addingTimeInterval(-5400)
        let newStop = Date().addingTimeInterval(-1800)
        let cmd = makeEdit(session: session.id,
                           start: editDateFormatter.string(from:newStart),
                           stop: editDateFormatter.string(from:newStop))
        try cmd.execute(ctx: ctx)

        let updated = try sessionRepo.get(id: session.id)!
        #expect(abs(updated.startTime.timeIntervalSince(newStart)) < 60)
        #expect(abs(updated.endTime!.timeIntervalSince(newStop)) < 60)
    }

    @Test("edit with --duration only keeps start, computes stop")
    func editDurationOnly() throws {
        let (ctx, projectRepo, sessionRepo) = buildCtx()
        let proj = try projectRepo.create(name: "acme-corp", slug: "acme-corp")
        let originalStart = Date().addingTimeInterval(-7200)
        let session = try sessionRepo.create(projectId: proj.id,
                                             startTime: originalStart,
                                             endTime: Date().addingTimeInterval(-3600))

        let cmd = makeEdit(session: session.id, duration: 1800)
        try cmd.execute(ctx: ctx)

        let updated = try sessionRepo.get(id: session.id)!
        #expect(abs(updated.startTime.timeIntervalSince(originalStart)) < 1)
        let expectedStop = originalStart.addingTimeInterval(1800)
        #expect(abs(updated.endTime!.timeIntervalSince(expectedStop)) < 1)
    }

    @Test("edit with --start and --duration sets start and computes stop")
    func editStartAndDuration() throws {
        let (ctx, projectRepo, sessionRepo) = buildCtx()
        let proj = try projectRepo.create(name: "acme-corp", slug: "acme-corp")
        let session = try sessionRepo.create(projectId: proj.id,
                                             startTime: Date().addingTimeInterval(-7200),
                                             endTime: Date().addingTimeInterval(-3600))

        let newStart = Date().addingTimeInterval(-5400)
        let cmd = makeEdit(session: session.id,
                           start: editDateFormatter.string(from:newStart),
                           duration: 1800)
        try cmd.execute(ctx: ctx)

        let updated = try sessionRepo.get(id: session.id)!
        #expect(abs(updated.startTime.timeIntervalSince(newStart)) < 60)
        let expectedStop = newStart.addingTimeInterval(1800)
        #expect(abs(updated.endTime!.timeIntervalSince(expectedStop)) < 60)
    }

    @Test("edit with --stop and --duration sets stop and computes start")
    func editStopAndDuration() throws {
        let (ctx, projectRepo, sessionRepo) = buildCtx()
        let proj = try projectRepo.create(name: "acme-corp", slug: "acme-corp")
        _ = try sessionRepo.create(projectId: proj.id,
                                   startTime: Date().addingTimeInterval(-7200),
                                   endTime: Date().addingTimeInterval(-3600))

        let newStop = Date().addingTimeInterval(-1800)
        let cmd = makeEdit(session: 1,
                           stop: editDateFormatter.string(from:newStop),
                           duration: 1800)
        try cmd.execute(ctx: ctx)

        let updated = try sessionRepo.get(id: 1)!
        let expectedStart = newStop.addingTimeInterval(-1800)
        #expect(abs(updated.startTime.timeIntervalSince(expectedStart)) < 60)
        #expect(abs(updated.endTime!.timeIntervalSince(newStop)) < 60)
    }

    // MARK: - Error cases

    @Test("edit with all three flags throws overdetermined")
    func editOverdetermined() throws {
        let (ctx, projectRepo, sessionRepo) = buildCtx()
        let proj = try projectRepo.create(name: "acme-corp", slug: "acme-corp")
        _ = try sessionRepo.create(projectId: proj.id,
                                   startTime: Date().addingTimeInterval(-7200),
                                   endTime: Date().addingTimeInterval(-3600))

        let cmd = makeEdit(session: 1,
                           start: editDateFormatter.string(from:Date().addingTimeInterval(-5400)),
                           stop: editDateFormatter.string(from:Date().addingTimeInterval(-1800)),
                           duration: 1800)

        #expect(throws: RockyCoreError.self) {
            try cmd.execute(ctx: ctx)
        }
    }

    @Test("edit non-existent session throws sessionNotFound")
    func editSessionNotFound() throws {
        let (ctx, _, _) = buildCtx()

        let cmd = makeEdit(session: 999,
                           start: editDateFormatter.string(from:Date().addingTimeInterval(-3600)))

        #expect(throws: RockyCoreError.self) {
            try cmd.execute(ctx: ctx)
        }
    }

    @Test("edit stop of running session throws cannotEditRunningSessionStop")
    func editRunningSessionStop() throws {
        let (ctx, projectRepo, sessionRepo) = buildCtx()
        let proj = try projectRepo.create(name: "acme-corp", slug: "acme-corp")
        let session = try sessionRepo.create(projectId: proj.id,
                                             startTime: Date().addingTimeInterval(-3600),
                                             endTime: nil)

        let cmd = makeEdit(session: session.id,
                           stop: editDateFormatter.string(from:Date().addingTimeInterval(-1800)))

        #expect(throws: RockyCoreError.self) {
            try cmd.execute(ctx: ctx)
        }
    }

    @Test("edit start in future throws startTimeInFuture")
    func editStartInFuture() throws {
        let (ctx, projectRepo, sessionRepo) = buildCtx()
        let proj = try projectRepo.create(name: "acme-corp", slug: "acme-corp")
        let session = try sessionRepo.create(projectId: proj.id,
                                             startTime: Date().addingTimeInterval(-7200),
                                             endTime: Date().addingTimeInterval(-3600))

        let cmd = makeEdit(session: session.id,
                           start: editDateFormatter.string(from:Date().addingTimeInterval(7200)))

        #expect(throws: RockyCoreError.self) {
            try cmd.execute(ctx: ctx)
        }
    }

    @Test("edit with stop before start throws stopBeforeStart")
    func editStopBeforeStart() throws {
        let (ctx, projectRepo, sessionRepo) = buildCtx()
        let proj = try projectRepo.create(name: "acme-corp", slug: "acme-corp")
        let session = try sessionRepo.create(projectId: proj.id,
                                             startTime: Date().addingTimeInterval(-7200),
                                             endTime: Date().addingTimeInterval(-3600))

        let cmd = makeEdit(session: session.id,
                           start: editDateFormatter.string(from:Date().addingTimeInterval(-1800)),
                           stop: editDateFormatter.string(from:Date().addingTimeInterval(-3600)))

        #expect(throws: RockyCoreError.self) {
            try cmd.execute(ctx: ctx)
        }
    }

    @Test("edit with zero duration throws durationNotPositive")
    func editZeroDuration() throws {
        let (ctx, projectRepo, sessionRepo) = buildCtx()
        let proj = try projectRepo.create(name: "acme-corp", slug: "acme-corp")
        let session = try sessionRepo.create(projectId: proj.id,
                                             startTime: Date().addingTimeInterval(-7200),
                                             endTime: Date().addingTimeInterval(-3600))

        let cmd = makeEdit(session: session.id, duration: 0)

        #expect(throws: RockyCoreError.self) {
            try cmd.execute(ctx: ctx)
        }
    }

    @Test("edit with negative duration throws durationNotPositive")
    func editNegativeDuration() throws {
        let (ctx, projectRepo, sessionRepo) = buildCtx()
        let proj = try projectRepo.create(name: "acme-corp", slug: "acme-corp")
        let session = try sessionRepo.create(projectId: proj.id,
                                             startTime: Date().addingTimeInterval(-7200),
                                             endTime: Date().addingTimeInterval(-3600))

        let cmd = makeEdit(session: session.id, duration: -600)

        #expect(throws: RockyCoreError.self) {
            try cmd.execute(ctx: ctx)
        }
    }

    @Test("edit start of running session is allowed")
    func editRunningSessionStart() throws {
        let (ctx, projectRepo, sessionRepo) = buildCtx()
        let proj = try projectRepo.create(name: "acme-corp", slug: "acme-corp")
        let session = try sessionRepo.create(projectId: proj.id,
                                             startTime: Date().addingTimeInterval(-3600),
                                             endTime: nil)

        let newStart = Date().addingTimeInterval(-7200)
        let cmd = makeEdit(session: session.id,
                           start: editDateFormatter.string(from:newStart))
        try cmd.execute(ctx: ctx)

        let updated = try sessionRepo.get(id: session.id)!
        #expect(abs(updated.startTime.timeIntervalSince(newStart)) < 60)
        #expect(updated.isRunning)
    }

    @Test("edit session spanning midnight")
    func editSessionSpanningMidnight() throws {
        let (ctx, projectRepo, sessionRepo) = buildCtx()
        let proj = try projectRepo.create(name: "acme-corp", slug: "acme-corp")

        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: Date()))!
        let startTime = calendar.date(bySettingHour: 23, minute: 0, second: 0, of: yesterday)!
        let endTime = calendar.date(bySettingHour: 1, minute: 0, second: 0, of: Date())!

        let session = try sessionRepo.create(projectId: proj.id,
                                             startTime: startTime, endTime: endTime)

        let cmd = makeEdit(session: session.id, duration: 10800) // 3 hours
        try cmd.execute(ctx: ctx)

        let updated = try sessionRepo.get(id: session.id)!
        #expect(abs(updated.startTime.timeIntervalSince(startTime)) < 1)
        let expectedStop = startTime.addingTimeInterval(10800)
        #expect(abs(updated.endTime!.timeIntervalSince(expectedStop)) < 1)
    }

    @Test("edit with no flags and --session returns session unchanged")
    func editNoFlags() throws {
        let (ctx, projectRepo, sessionRepo) = buildCtx()
        let proj = try projectRepo.create(name: "acme-corp", slug: "acme-corp")
        let originalStart = Date().addingTimeInterval(-7200)
        let originalStop = Date().addingTimeInterval(-3600)
        let session = try sessionRepo.create(projectId: proj.id,
                                             startTime: originalStart, endTime: originalStop)

        let cmd = makeEdit(session: session.id)
        try cmd.execute(ctx: ctx)

        let updated = try sessionRepo.get(id: session.id)!
        #expect(abs(updated.startTime.timeIntervalSince(originalStart)) < 1)
        #expect(abs(updated.endTime!.timeIntervalSince(originalStop)) < 1)
    }
}
