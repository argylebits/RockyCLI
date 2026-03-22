import Testing
import Foundation
@testable import RockyCore

@Suite("SessionRepository")
struct SessionRepositoryTests {

    // MARK: - create

    @Test("create returns session with correct projectId")
    func createReturnsSession() throws {
        let projectRepo = MockProjectRepository()
        let sessionRepo = MockSessionRepository(projectRepository: projectRepo)
        let project = try projectRepo.create(name: "acme-corp", slug: "acme-corp".slugified)

        let session = try sessionRepo.create(projectId: project.id, startTime: Date(), endTime: nil)
        #expect(session.projectId == project.id)
        #expect(session.id > 0)
    }

    @Test("create with nil endTime produces a running session")
    func createRunningSession() throws {
        let projectRepo = MockProjectRepository()
        let sessionRepo = MockSessionRepository(projectRepository: projectRepo)
        let project = try projectRepo.create(name: "acme-corp", slug: "acme-corp".slugified)

        let session = try sessionRepo.create(projectId: project.id, startTime: Date(), endTime: nil)
        #expect(session.isRunning)
    }

    @Test("create with endTime produces a completed session")
    func createCompletedSession() throws {
        let projectRepo = MockProjectRepository()
        let sessionRepo = MockSessionRepository(projectRepository: projectRepo)
        let project = try projectRepo.create(name: "acme-corp", slug: "acme-corp".slugified)
        let cal = Calendar.current
        let start = cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 10))!
        let end = cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 11))!

        let session = try sessionRepo.create(projectId: project.id, startTime: start, endTime: end)
        #expect(!session.isRunning)
        #expect(session.startTime == start)
        #expect(session.endTime == end)
    }

    @Test("create assigns unique ids")
    func createUniqueIds() throws {
        let projectRepo = MockProjectRepository()
        let sessionRepo = MockSessionRepository(projectRepository: projectRepo)
        let project = try projectRepo.create(name: "acme-corp", slug: "acme-corp".slugified)

        let s1 = try sessionRepo.create(projectId: project.id, startTime: Date(), endTime: nil)
        let s2 = try sessionRepo.create(projectId: project.id, startTime: Date(), endTime: nil)
        #expect(s1.id != s2.id)
    }

    // MARK: - get

    @Test("get returns session by id")
    func getById() throws {
        let projectRepo = MockProjectRepository()
        let sessionRepo = MockSessionRepository(projectRepository: projectRepo)
        let project = try projectRepo.create(name: "acme-corp", slug: "acme-corp".slugified)
        let cal = Calendar.current
        let start = cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 10))!
        let end = cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 11))!

        let created = try sessionRepo.create(projectId: project.id, startTime: start, endTime: end)
        let found = try sessionRepo.get(id: created.id)
        #expect(found != nil)
        #expect(found?.startTime == start)
        #expect(found?.endTime == end)
    }

    @Test("get returns nil for unknown id")
    func getByIdUnknown() throws {
        let projectRepo = MockProjectRepository()
        let sessionRepo = MockSessionRepository(projectRepository: projectRepo)
        let found = try sessionRepo.get(id: 999)
        #expect(found == nil)
    }

    // MARK: - list

    @Test("list with no filters returns all sessions with projects")
    func listAll() throws {
        let projectRepo = MockProjectRepository()
        let sessionRepo = MockSessionRepository(projectRepository: projectRepo)
        let cal = Calendar.current
        let p1 = try projectRepo.create(name: "project-1", slug: "project-1".slugified)
        let p2 = try projectRepo.create(name: "project-2", slug: "project-2".slugified)

        let start = cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 10))!
        let end = cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 11))!
        _ = try sessionRepo.create(projectId: p1.id, startTime: start, endTime: end)
        _ = try sessionRepo.create(projectId: p2.id, startTime: start, endTime: nil)

        let results = try sessionRepo.list(running: nil, from: nil, to: nil, projectId: nil)
        #expect(results.count == 2)
    }

    @Test("list running true returns only running sessions")
    func listRunningOnly() throws {
        let projectRepo = MockProjectRepository()
        let sessionRepo = MockSessionRepository(projectRepository: projectRepo)
        let cal = Calendar.current
        let project = try projectRepo.create(name: "acme-corp", slug: "acme-corp".slugified)

        let start = cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 10))!
        let end = cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 11))!
        _ = try sessionRepo.create(projectId: project.id, startTime: start, endTime: end)
        _ = try sessionRepo.create(projectId: project.id, startTime: Date(), endTime: nil)

        let results = try sessionRepo.list(running: true, from: nil, to: nil, projectId: nil)
        #expect(results.count == 1)
        #expect(results[0].0.isRunning)
    }

    @Test("list running false returns only completed sessions")
    func listCompletedOnly() throws {
        let projectRepo = MockProjectRepository()
        let sessionRepo = MockSessionRepository(projectRepository: projectRepo)
        let cal = Calendar.current
        let project = try projectRepo.create(name: "acme-corp", slug: "acme-corp".slugified)

        let start = cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 10))!
        let end = cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 11))!
        _ = try sessionRepo.create(projectId: project.id, startTime: start, endTime: end)
        _ = try sessionRepo.create(projectId: project.id, startTime: Date(), endTime: nil)

        let results = try sessionRepo.list(running: false, from: nil, to: nil, projectId: nil)
        #expect(results.count == 1)
        #expect(!results[0].0.isRunning)
    }

    @Test("list with date range returns overlapping sessions")
    func listDateRange() throws {
        let projectRepo = MockProjectRepository()
        let sessionRepo = MockSessionRepository(projectRepository: projectRepo)
        let cal = Calendar.current
        let project = try projectRepo.create(name: "test", slug: "test".slugified)

        // Inside range
        _ = try sessionRepo.create(projectId: project.id,
            startTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 10))!,
            endTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 11))!)
        // Outside range
        _ = try sessionRepo.create(projectId: project.id,
            startTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 5, hour: 10))!,
            endTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 5, hour: 11))!)
        // Overlapping range boundary
        _ = try sessionRepo.create(projectId: project.id,
            startTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 5, hour: 23))!,
            endTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 1))!)

        let from = cal.date(from: DateComponents(year: 2026, month: 3, day: 6))!
        let to = cal.date(from: DateComponents(year: 2026, month: 3, day: 7))!
        let results = try sessionRepo.list(running: nil, from: from, to: to, projectId: nil)

        #expect(results.count == 2)
    }

    @Test("list excludes sessions outside the date range")
    func listExcludesOutsideRange() throws {
        let projectRepo = MockProjectRepository()
        let sessionRepo = MockSessionRepository(projectRepository: projectRepo)
        let cal = Calendar.current
        let project = try projectRepo.create(name: "test", slug: "test".slugified)

        _ = try sessionRepo.create(projectId: project.id,
            startTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 1, hour: 10))!,
            endTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 1, hour: 11))!)

        let from = cal.date(from: DateComponents(year: 2026, month: 3, day: 6))!
        let to = cal.date(from: DateComponents(year: 2026, month: 3, day: 7))!
        let results = try sessionRepo.list(running: nil, from: from, to: to, projectId: nil)

        #expect(results.isEmpty)
    }

    @Test("list filters by projectId")
    func listFilterByProject() throws {
        let projectRepo = MockProjectRepository()
        let sessionRepo = MockSessionRepository(projectRepository: projectRepo)
        let cal = Calendar.current
        let p1 = try projectRepo.create(name: "included", slug: "included".slugified)
        let p2 = try projectRepo.create(name: "excluded", slug: "excluded".slugified)

        let start = cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 10))!
        let end = cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 11))!
        _ = try sessionRepo.create(projectId: p1.id, startTime: start, endTime: end)
        _ = try sessionRepo.create(projectId: p2.id, startTime: start, endTime: end)

        let results = try sessionRepo.list(running: nil, from: nil, to: nil, projectId: p1.id)

        #expect(results.count == 1)
        #expect(results[0].1.name == "included")
    }

    @Test("list running true with projectId filters both")
    func listRunningAndProject() throws {
        let projectRepo = MockProjectRepository()
        let sessionRepo = MockSessionRepository(projectRepository: projectRepo)
        let cal = Calendar.current
        let p1 = try projectRepo.create(name: "project-1", slug: "project-1".slugified)
        let p2 = try projectRepo.create(name: "project-2", slug: "project-2".slugified)

        let start = cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 10))!
        let end = cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 11))!

        // p1 running
        _ = try sessionRepo.create(projectId: p1.id, startTime: Date(), endTime: nil)
        // p1 completed
        _ = try sessionRepo.create(projectId: p1.id, startTime: start, endTime: end)
        // p2 running
        _ = try sessionRepo.create(projectId: p2.id, startTime: Date(), endTime: nil)

        let results = try sessionRepo.list(running: true, from: nil, to: nil, projectId: p1.id)
        #expect(results.count == 1)
        #expect(results[0].0.isRunning)
        #expect(results[0].1.name == "project-1")
    }

    @Test("list returns results sorted by start time ascending")
    func listSortedByStartTime() throws {
        let projectRepo = MockProjectRepository()
        let sessionRepo = MockSessionRepository(projectRepository: projectRepo)
        let cal = Calendar.current
        let project = try projectRepo.create(name: "test", slug: "test".slugified)

        let later = cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 14))!
        let earlier = cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 10))!
        let end = cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 15))!

        // Insert later first
        _ = try sessionRepo.create(projectId: project.id, startTime: later, endTime: end)
        _ = try sessionRepo.create(projectId: project.id, startTime: earlier, endTime: end)

        let results = try sessionRepo.list(running: nil, from: nil, to: nil, projectId: nil)
        #expect(results[0].0.startTime == earlier)
        #expect(results[1].0.startTime == later)
    }

    @Test("list returns project data alongside session")
    func listIncludesProjectData() throws {
        let projectRepo = MockProjectRepository()
        let sessionRepo = MockSessionRepository(projectRepository: projectRepo)
        let project = try projectRepo.create(name: "Acme Corp", slug: "Acme Corp".slugified)

        _ = try sessionRepo.create(projectId: project.id, startTime: Date(), endTime: nil)

        let results = try sessionRepo.list(running: nil, from: nil, to: nil, projectId: nil)
        #expect(results.count == 1)
        #expect(results[0].1.name == "Acme Corp")
        #expect(results[0].1.slug == "acme-corp")
    }

    // MARK: - update

    @Test("update modifies session times")
    func updateTimes() throws {
        let projectRepo = MockProjectRepository()
        let sessionRepo = MockSessionRepository(projectRepository: projectRepo)
        let cal = Calendar.current
        let project = try projectRepo.create(name: "test", slug: "test".slugified)
        let start = cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 10))!
        let end = cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 11))!

        let created = try sessionRepo.create(projectId: project.id, startTime: start, endTime: end)

        let newStart = cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 9))!
        let newEnd = cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 12))!
        let updated = try sessionRepo.update(id: created.id, startTime: newStart, endTime: newEnd)

        #expect(updated.startTime == newStart)
        #expect(updated.endTime == newEnd)
    }

    @Test("update persists changes")
    func updatePersists() throws {
        let projectRepo = MockProjectRepository()
        let sessionRepo = MockSessionRepository(projectRepository: projectRepo)
        let cal = Calendar.current
        let project = try projectRepo.create(name: "test", slug: "test".slugified)
        let start = cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 10))!
        let end = cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 11))!

        let created = try sessionRepo.create(projectId: project.id, startTime: start, endTime: end)

        let newStart = cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 9))!
        let newEnd = cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 12))!
        _ = try sessionRepo.update(id: created.id, startTime: newStart, endTime: newEnd)

        let fetched = try sessionRepo.get(id: created.id)
        #expect(fetched?.startTime == newStart)
        #expect(fetched?.endTime == newEnd)
    }

    @Test("update throws for unknown id")
    func updateUnknownId() throws {
        let projectRepo = MockProjectRepository()
        let sessionRepo = MockSessionRepository(projectRepository: projectRepo)
        #expect(throws: RockyError.self) {
            try sessionRepo.update(id: 999, startTime: Date(), endTime: nil)
        }
    }

    @Test("update can set endTime to nil (reopen session)")
    func updateReopenSession() throws {
        let projectRepo = MockProjectRepository()
        let sessionRepo = MockSessionRepository(projectRepository: projectRepo)
        let cal = Calendar.current
        let project = try projectRepo.create(name: "test", slug: "test".slugified)
        let start = cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 10))!
        let end = cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 11))!

        let created = try sessionRepo.create(projectId: project.id, startTime: start, endTime: end)
        let updated = try sessionRepo.update(id: created.id, startTime: start, endTime: nil)

        #expect(updated.isRunning)
    }

    @Test("update preserves projectId")
    func updatePreservesProjectId() throws {
        let projectRepo = MockProjectRepository()
        let sessionRepo = MockSessionRepository(projectRepository: projectRepo)
        let project = try projectRepo.create(name: "test", slug: "test".slugified)

        let created = try sessionRepo.create(projectId: project.id, startTime: Date(), endTime: nil)
        let updated = try sessionRepo.update(id: created.id, startTime: Date(), endTime: Date())

        #expect(updated.projectId == project.id)
    }
}
