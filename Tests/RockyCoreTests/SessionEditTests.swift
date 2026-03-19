import Testing
import Foundation
@testable import RockyCore

@Suite("SessionService.editSession")
struct SessionEditTests {
    private func makeServices() -> (MockProjectRepository, MockSessionRepository, SessionService) {
        let projectRepo = MockProjectRepository()
        let sessionRepo = MockSessionRepository(projectRepository: projectRepo)
        let sessionService = SessionService(repository: sessionRepo)
        return (projectRepo, sessionRepo, sessionService)
    }

    private let cal = Calendar.current

    private func insertSession(
        _ sessionRepo: MockSessionRepository,
        projectId: Int,
        startHour: Int, startDay: Int = 6,
        endHour: Int, endDay: Int = 6
    ) throws {
        let start = cal.date(from: DateComponents(year: 2026, month: 3, day: startDay, hour: startHour))!
        let end = cal.date(from: DateComponents(year: 2026, month: 3, day: endDay, hour: endHour))!
        try sessionRepo.insert(projectId: projectId, startTime: start, endTime: end)
    }

    @Test("edit with --start only updates start, keeps stop")
    func editStartOnly() throws {
        let (projectRepo, sessionRepo, service) = makeServices()
        let project = try projectRepo.findOrCreate(name: "test", slug: "test".slugified)
        try insertSession(sessionRepo, projectId: project.id, startHour: 10, endHour: 12)

        let all = try sessionRepo.getSessions(
            from: cal.date(from: DateComponents(year: 2026, month: 3, day: 6))!,
            to: cal.date(from: DateComponents(year: 2026, month: 3, day: 7))!
        )
        let sessionId = all[0].0.id
        let originalEnd = all[0].0.endTime!

        let newStart = cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 9))!
        let updated = try service.editSession(id: sessionId, newStart: newStart, newStop: nil, newDuration: nil)

        #expect(updated.startTime == newStart)
        #expect(updated.endTime == originalEnd)
    }

    @Test("edit with --stop only updates stop, keeps start")
    func editStopOnly() throws {
        let (projectRepo, sessionRepo, service) = makeServices()
        let project = try projectRepo.findOrCreate(name: "test", slug: "test".slugified)
        try insertSession(sessionRepo, projectId: project.id, startHour: 10, endHour: 12)

        let all = try sessionRepo.getSessions(
            from: cal.date(from: DateComponents(year: 2026, month: 3, day: 6))!,
            to: cal.date(from: DateComponents(year: 2026, month: 3, day: 7))!
        )
        let sessionId = all[0].0.id
        let originalStart = all[0].0.startTime

        let newStop = cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 14))!
        let updated = try service.editSession(id: sessionId, newStart: nil, newStop: newStop, newDuration: nil)

        #expect(updated.startTime == originalStart)
        #expect(updated.endTime == newStop)
    }

    @Test("edit with --start + --stop updates both")
    func editStartAndStop() throws {
        let (projectRepo, sessionRepo, service) = makeServices()
        let project = try projectRepo.findOrCreate(name: "test", slug: "test".slugified)
        try insertSession(sessionRepo, projectId: project.id, startHour: 10, endHour: 12)

        let all = try sessionRepo.getSessions(
            from: cal.date(from: DateComponents(year: 2026, month: 3, day: 6))!,
            to: cal.date(from: DateComponents(year: 2026, month: 3, day: 7))!
        )
        let sessionId = all[0].0.id

        let newStart = cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 9))!
        let newStop = cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 11))!
        let updated = try service.editSession(id: sessionId, newStart: newStart, newStop: newStop, newDuration: nil)

        #expect(updated.startTime == newStart)
        #expect(updated.endTime == newStop)
    }

    @Test("edit with --duration only keeps start, computes stop")
    func editDurationOnly() throws {
        let (projectRepo, sessionRepo, service) = makeServices()
        let project = try projectRepo.findOrCreate(name: "test", slug: "test".slugified)
        try insertSession(sessionRepo, projectId: project.id, startHour: 10, endHour: 12)

        let all = try sessionRepo.getSessions(
            from: cal.date(from: DateComponents(year: 2026, month: 3, day: 6))!,
            to: cal.date(from: DateComponents(year: 2026, month: 3, day: 7))!
        )
        let sessionId = all[0].0.id
        let originalStart = all[0].0.startTime

        let updated = try service.editSession(id: sessionId, newStart: nil, newStop: nil, newDuration: 3600)

        #expect(updated.startTime == originalStart)
        #expect(abs(updated.endTime!.timeIntervalSince(originalStart) - 3600) < 1)
    }

    @Test("edit with --start + --duration sets start and computes stop")
    func editStartAndDuration() throws {
        let (projectRepo, sessionRepo, service) = makeServices()
        let project = try projectRepo.findOrCreate(name: "test", slug: "test".slugified)
        try insertSession(sessionRepo, projectId: project.id, startHour: 10, endHour: 12)

        let all = try sessionRepo.getSessions(
            from: cal.date(from: DateComponents(year: 2026, month: 3, day: 6))!,
            to: cal.date(from: DateComponents(year: 2026, month: 3, day: 7))!
        )
        let sessionId = all[0].0.id

        let newStart = cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 9))!
        let updated = try service.editSession(id: sessionId, newStart: newStart, newStop: nil, newDuration: 5400)

        #expect(updated.startTime == newStart)
        #expect(abs(updated.endTime!.timeIntervalSince(newStart) - 5400) < 1)
    }

    @Test("edit with --stop + --duration sets stop and computes start")
    func editStopAndDuration() throws {
        let (projectRepo, sessionRepo, service) = makeServices()
        let project = try projectRepo.findOrCreate(name: "test", slug: "test".slugified)
        try insertSession(sessionRepo, projectId: project.id, startHour: 10, endHour: 12)

        let all = try sessionRepo.getSessions(
            from: cal.date(from: DateComponents(year: 2026, month: 3, day: 6))!,
            to: cal.date(from: DateComponents(year: 2026, month: 3, day: 7))!
        )
        let sessionId = all[0].0.id

        let newStop = cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 14))!
        let updated = try service.editSession(id: sessionId, newStart: nil, newStop: newStop, newDuration: 7200)

        #expect(abs(updated.startTime.timeIntervalSince(newStop) + 7200) < 1)
        #expect(updated.endTime == newStop)
    }

    @Test("edit with all three flags throws overdetermined")
    func editOverdetermined() throws {
        let (projectRepo, sessionRepo, service) = makeServices()
        let project = try projectRepo.findOrCreate(name: "test", slug: "test".slugified)
        try insertSession(sessionRepo, projectId: project.id, startHour: 10, endHour: 12)

        let all = try sessionRepo.getSessions(
            from: cal.date(from: DateComponents(year: 2026, month: 3, day: 6))!,
            to: cal.date(from: DateComponents(year: 2026, month: 3, day: 7))!
        )
        let sessionId = all[0].0.id

        let newStart = cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 9))!
        let newStop = cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 11))!

        #expect(throws: RockyCoreError.self) {
            try service.editSession(id: sessionId, newStart: newStart, newStop: newStop, newDuration: 3600)
        }
    }

    @Test("edit non-existent session throws sessionNotFound")
    func editNotFound() throws {
        let (_, _, service) = makeServices()

        #expect(throws: RockyCoreError.self) {
            try service.editSession(id: 999, newStart: Date(), newStop: nil, newDuration: nil)
        }
    }

    @Test("edit stop of running session throws cannotEditRunningSessionStop")
    func editRunningStop() throws {
        let (projectRepo, sessionRepo, service) = makeServices()
        let project = try projectRepo.findOrCreate(name: "test", slug: "test".slugified)
        try sessionRepo.start(projectId: project.id)

        let running = try sessionRepo.getRunning()
        let sessionId = running[0].id

        #expect(throws: RockyCoreError.self) {
            try service.editSession(id: sessionId, newStart: nil, newStop: Date(), newDuration: nil)
        }
    }

    @Test("edit start in future throws startTimeInFuture")
    func editFutureStart() throws {
        let (projectRepo, sessionRepo, service) = makeServices()
        let project = try projectRepo.findOrCreate(name: "test", slug: "test".slugified)
        try insertSession(sessionRepo, projectId: project.id, startHour: 10, endHour: 12)

        let all = try sessionRepo.getSessions(
            from: cal.date(from: DateComponents(year: 2026, month: 3, day: 6))!,
            to: cal.date(from: DateComponents(year: 2026, month: 3, day: 7))!
        )
        let sessionId = all[0].0.id

        let futureStart = Date().addingTimeInterval(86400)

        #expect(throws: RockyCoreError.self) {
            try service.editSession(id: sessionId, newStart: futureStart, newStop: nil, newDuration: nil)
        }
    }

    @Test("edit with stop before start throws stopBeforeStart")
    func editStopBeforeStart() throws {
        let (projectRepo, sessionRepo, service) = makeServices()
        let project = try projectRepo.findOrCreate(name: "test", slug: "test".slugified)
        try insertSession(sessionRepo, projectId: project.id, startHour: 10, endHour: 12)

        let all = try sessionRepo.getSessions(
            from: cal.date(from: DateComponents(year: 2026, month: 3, day: 6))!,
            to: cal.date(from: DateComponents(year: 2026, month: 3, day: 7))!
        )
        let sessionId = all[0].0.id

        let badStop = cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 9))!

        #expect(throws: RockyCoreError.self) {
            try service.editSession(id: sessionId, newStart: nil, newStop: badStop, newDuration: nil)
        }
    }

    @Test("edit with zero duration throws durationNotPositive")
    func editZeroDuration() throws {
        let (projectRepo, sessionRepo, service) = makeServices()
        let project = try projectRepo.findOrCreate(name: "test", slug: "test".slugified)
        try insertSession(sessionRepo, projectId: project.id, startHour: 10, endHour: 12)

        let all = try sessionRepo.getSessions(
            from: cal.date(from: DateComponents(year: 2026, month: 3, day: 6))!,
            to: cal.date(from: DateComponents(year: 2026, month: 3, day: 7))!
        )
        let sessionId = all[0].0.id

        #expect(throws: RockyCoreError.self) {
            try service.editSession(id: sessionId, newStart: nil, newStop: nil, newDuration: 0)
        }
    }

    @Test("edit with negative duration throws durationNotPositive")
    func editNegativeDuration() throws {
        let (projectRepo, sessionRepo, service) = makeServices()
        let project = try projectRepo.findOrCreate(name: "test", slug: "test".slugified)
        try insertSession(sessionRepo, projectId: project.id, startHour: 10, endHour: 12)

        let all = try sessionRepo.getSessions(
            from: cal.date(from: DateComponents(year: 2026, month: 3, day: 6))!,
            to: cal.date(from: DateComponents(year: 2026, month: 3, day: 7))!
        )
        let sessionId = all[0].0.id

        #expect(throws: RockyCoreError.self) {
            try service.editSession(id: sessionId, newStart: nil, newStop: nil, newDuration: -100)
        }
    }

    @Test("edit start of running session is allowed")
    func editRunningStart() throws {
        let (projectRepo, sessionRepo, service) = makeServices()
        let project = try projectRepo.findOrCreate(name: "test", slug: "test".slugified)
        try sessionRepo.start(projectId: project.id)

        let running = try sessionRepo.getRunning()
        let sessionId = running[0].id

        let newStart = Date().addingTimeInterval(-7200)
        let updated = try service.editSession(id: sessionId, newStart: newStart, newStop: nil, newDuration: nil)

        #expect(abs(updated.startTime.timeIntervalSince(newStart)) < 1)
        #expect(updated.isRunning)
    }

    @Test("edit session spanning midnight")
    func editMidnightSession() throws {
        let (projectRepo, sessionRepo, service) = makeServices()
        let project = try projectRepo.findOrCreate(name: "test", slug: "test".slugified)
        try insertSession(sessionRepo, projectId: project.id, startHour: 23, startDay: 5, endHour: 10, endDay: 6)

        let all = try sessionRepo.getSessions(
            from: cal.date(from: DateComponents(year: 2026, month: 3, day: 5))!,
            to: cal.date(from: DateComponents(year: 2026, month: 3, day: 7))!
        )
        let sessionId = all[0].0.id

        let newStop = cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 1, minute: 30))!
        let updated = try service.editSession(id: sessionId, newStart: nil, newStop: newStop, newDuration: nil)

        #expect(updated.endTime == newStop)
        #expect(updated.duration() == 9000) // 2.5 hours
    }
}
