import Testing
import Foundation
@testable import RockyCore

@Suite("SessionService")
struct SessionServiceTests {
    private func makeServices() -> (MockProjectRepository, MockSessionRepository, SessionService) {
        let projectRepo = MockProjectRepository()
        let sessionRepo = MockSessionRepository(projectRepository: projectRepo)
        let service = SessionService(repository: sessionRepo)
        return (projectRepo, sessionRepo, service)
    }

    // MARK: - create

    @Test("create starts a running session with startTime=now and endTime=nil")
    func createStartsRunning() throws {
        let (projectRepo, _, service) = makeServices()
        let project = try projectRepo.create(name: "acme-corp", slug: "acme-corp".slugified)

        try service.create(projectId: project.id)

        let running = try service.list(running: true)
        #expect(running.count == 1)
        #expect(running[0].0.projectId == project.id)
        #expect(running[0].0.isRunning)
    }

    @Test("create allows multiple running sessions on different projects")
    func createMultipleProjects() throws {
        let (projectRepo, _, service) = makeServices()
        let p1 = try projectRepo.create(name: "project-1", slug: "project-1".slugified)
        let p2 = try projectRepo.create(name: "project-2", slug: "project-2".slugified)

        try service.create(projectId: p1.id)
        try service.create(projectId: p2.id)

        let running = try service.list(running: true)
        #expect(running.count == 2)
    }

    // MARK: - list

    @Test("list running true returns running sessions with projects")
    func listRunning() throws {
        let (projectRepo, _, service) = makeServices()
        let project = try projectRepo.create(name: "acme-corp", slug: "acme-corp".slugified)
        try service.create(projectId: project.id)

        let running = try service.list(running: true)
        #expect(running.count == 1)
        #expect(running[0].1.name == "acme-corp")
    }

    @Test("list with date range returns sessions in range")
    func listDateRange() throws {
        let (projectRepo, sessionRepo, service) = makeServices()
        let cal = Calendar.current
        let project = try projectRepo.create(name: "test", slug: "test".slugified)

        _ = try sessionRepo.create(projectId: project.id,
            startTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 10))!,
            endTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 11))!)
        _ = try sessionRepo.create(projectId: project.id,
            startTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 1, hour: 10))!,
            endTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 1, hour: 11))!)

        let from = cal.date(from: DateComponents(year: 2026, month: 3, day: 6))!
        let to = cal.date(from: DateComponents(year: 2026, month: 3, day: 7))!
        let results = try service.list(from: from, to: to)
        #expect(results.count == 1)
    }

    // MARK: - get

    @Test("get returns session by id")
    func getById() throws {
        let (projectRepo, sessionRepo, service) = makeServices()
        let project = try projectRepo.create(name: "test", slug: "test".slugified)
        let cal = Calendar.current
        let start = cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 10))!
        let end = cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 11))!
        let created = try sessionRepo.create(projectId: project.id, startTime: start, endTime: end)

        let found = try service.get(id: created.id)
        #expect(found != nil)
        #expect(found?.startTime == start)
    }

    @Test("get returns nil for unknown id")
    func getByIdUnknown() throws {
        let (_, _, service) = makeServices()
        let found = try service.get(id: 999)
        #expect(found == nil)
    }

    // MARK: - update (validation logic)

    @Test("update with overdetermined flags throws")
    func updateOverdetermined() throws {
        let (projectRepo, sessionRepo, service) = makeServices()
        let project = try projectRepo.create(name: "test", slug: "test".slugified)
        let cal = Calendar.current
        let start = cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 10))!
        let end = cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 11))!
        let created = try sessionRepo.create(projectId: project.id, startTime: start, endTime: end)

        #expect(throws: RockyCoreError.self) {
            try service.update(id: created.id, newStart: start, newStop: end, newDuration: 3600)
        }
    }

    @Test("update with start only keeps existing stop")
    func updateStartOnly() throws {
        let (projectRepo, sessionRepo, service) = makeServices()
        let project = try projectRepo.create(name: "test", slug: "test".slugified)
        let cal = Calendar.current
        let start = cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 10))!
        let end = cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 12))!
        let created = try sessionRepo.create(projectId: project.id, startTime: start, endTime: end)

        let newStart = cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 9))!
        let updated = try service.update(id: created.id, newStart: newStart, newStop: nil, newDuration: nil)

        #expect(updated.startTime == newStart)
        #expect(updated.endTime == end)
    }

    @Test("update unknown id throws sessionNotFound")
    func updateNotFound() throws {
        let (_, _, service) = makeServices()
        #expect(throws: RockyCoreError.self) {
            try service.update(id: 999, newStart: Date(), newStop: nil, newDuration: nil)
        }
    }
}
