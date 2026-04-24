import Testing
import Foundation
@testable import RockyCore

@Suite("SessionRepository delete")
struct SessionRepositoryDeleteTests {

    private func buildRepos() -> (MockProjectRepository, MockSessionRepository) {
        let projectRepo = MockProjectRepository()
        let sessionRepo = MockSessionRepository(projectRepository: projectRepo)
        return (projectRepo, sessionRepo)
    }

    @Test("delete removes session by id")
    func deleteRemovesSession() throws {
        let (projectRepo, sessionRepo) = buildRepos()
        let proj = try projectRepo.create(name: "acme-corp", slug: "acme-corp")
        let session = try sessionRepo.create(projectId: proj.id, startTime: Date().addingTimeInterval(-3600), endTime: Date())

        try sessionRepo.delete(id: session.id)

        let found = try sessionRepo.get(id: session.id)
        #expect(found == nil)
    }

    @Test("delete throws for unknown id")
    func deleteUnknownId() throws {
        let (_, sessionRepo) = buildRepos()

        #expect(throws: RockyError.sessionNotFound(999)) {
            try sessionRepo.delete(id: 999)
        }
    }

    @Test("delete running session succeeds")
    func deleteRunningSession() throws {
        let (projectRepo, sessionRepo) = buildRepos()
        let proj = try projectRepo.create(name: "acme-corp", slug: "acme-corp")
        let session = try sessionRepo.create(projectId: proj.id, startTime: Date().addingTimeInterval(-3600), endTime: nil)

        try sessionRepo.delete(id: session.id)

        let found = try sessionRepo.get(id: session.id)
        #expect(found == nil)
    }

    @Test("delete does not affect other sessions")
    func deleteDoesNotAffectOthers() throws {
        let (projectRepo, sessionRepo) = buildRepos()
        let proj = try projectRepo.create(name: "acme-corp", slug: "acme-corp")
        let s1 = try sessionRepo.create(projectId: proj.id, startTime: Date().addingTimeInterval(-7200), endTime: Date().addingTimeInterval(-3600))
        let s2 = try sessionRepo.create(projectId: proj.id, startTime: Date().addingTimeInterval(-3600), endTime: Date())

        try sessionRepo.delete(id: s1.id)

        #expect(try sessionRepo.get(id: s1.id) == nil)
        #expect(try sessionRepo.get(id: s2.id) != nil)
    }
}

@Suite("ProjectRepository delete")
struct ProjectRepositoryDeleteTests {

    @Test("delete removes project by id")
    func deleteRemovesProject() throws {
        let repo = MockProjectRepository()
        let proj = try repo.create(name: "acme-corp", slug: "acme-corp")

        try repo.delete(id: proj.id)

        let found = try repo.get(id: proj.id)
        #expect(found == nil)
    }

    @Test("delete throws for unknown id")
    func deleteUnknownId() throws {
        let repo = MockProjectRepository()

        #expect(throws: RockyError.projectNotFound("999")) {
            try repo.delete(id: 999)
        }
    }

    @Test("delete does not affect other projects")
    func deleteDoesNotAffectOthers() throws {
        let repo = MockProjectRepository()
        let p1 = try repo.create(name: "project-a", slug: "project-a")
        let p2 = try repo.create(name: "project-b", slug: "project-b")

        try repo.delete(id: p1.id)

        #expect(try repo.get(id: p1.id) == nil)
        #expect(try repo.get(id: p2.id) != nil)
    }
}

@Suite("SessionService delete")
struct SessionServiceDeleteTests {

    private func buildCtx() -> (SessionService, MockProjectRepository, MockSessionRepository) {
        let projectRepo = MockProjectRepository()
        let sessionRepo = MockSessionRepository(projectRepository: projectRepo)
        let service = SessionService(repository: sessionRepo)
        return (service, projectRepo, sessionRepo)
    }

    @Test("delete removes session")
    func deleteRemovesSession() throws {
        let (service, projectRepo, sessionRepo) = buildCtx()
        let proj = try projectRepo.create(name: "acme-corp", slug: "acme-corp")
        let session = try sessionRepo.create(projectId: proj.id, startTime: Date().addingTimeInterval(-3600), endTime: Date())

        try service.delete(id: session.id)

        #expect(try sessionRepo.get(id: session.id) == nil)
    }

    @Test("delete throws for unknown id")
    func deleteUnknownId() throws {
        let (service, _, _) = buildCtx()

        #expect(throws: RockyError.sessionNotFound(999)) {
            try service.delete(id: 999)
        }
    }
}

@Suite("ProjectService delete")
struct ProjectServiceDeleteTests {

    private func buildCtx() -> (ProjectService, SessionService, MockProjectRepository, MockSessionRepository) {
        let projectRepo = MockProjectRepository()
        let sessionRepo = MockSessionRepository(projectRepository: projectRepo)
        let projectService = ProjectService(repository: projectRepo)
        let sessionService = SessionService(repository: sessionRepo)
        return (projectService, sessionService, projectRepo, sessionRepo)
    }

    @Test("delete removes project and returns session count")
    func deleteRemovesProject() throws {
        let (projectService, sessionService, projectRepo, sessionRepo) = buildCtx()
        let proj = try projectRepo.create(name: "acme-corp", slug: "acme-corp")
        _ = try sessionRepo.create(projectId: proj.id, startTime: Date().addingTimeInterval(-3600), endTime: Date())
        _ = try sessionRepo.create(projectId: proj.id, startTime: Date().addingTimeInterval(-1800), endTime: Date())

        let count = try projectService.delete(name: "acme-corp", sessionService: sessionService)

        #expect(count == 2)
        #expect(try projectRepo.get(id: proj.id) == nil)
    }

    @Test("delete removes associated sessions")
    func deleteRemovesSessions() throws {
        let (projectService, sessionService, projectRepo, sessionRepo) = buildCtx()
        let proj = try projectRepo.create(name: "acme-corp", slug: "acme-corp")
        let s1 = try sessionRepo.create(projectId: proj.id, startTime: Date().addingTimeInterval(-3600), endTime: Date())
        let s2 = try sessionRepo.create(projectId: proj.id, startTime: Date().addingTimeInterval(-1800), endTime: Date())

        _ = try projectService.delete(name: "acme-corp", sessionService: sessionService)

        #expect(try sessionRepo.get(id: s1.id) == nil)
        #expect(try sessionRepo.get(id: s2.id) == nil)
    }

    @Test("delete does not affect other project sessions")
    func deleteDoesNotAffectOtherSessions() throws {
        let (projectService, sessionService, projectRepo, sessionRepo) = buildCtx()
        let proj1 = try projectRepo.create(name: "project-a", slug: "project-a")
        let proj2 = try projectRepo.create(name: "project-b", slug: "project-b")
        _ = try sessionRepo.create(projectId: proj1.id, startTime: Date().addingTimeInterval(-3600), endTime: Date())
        let s2 = try sessionRepo.create(projectId: proj2.id, startTime: Date().addingTimeInterval(-1800), endTime: Date())

        _ = try projectService.delete(name: "project-a", sessionService: sessionService)

        #expect(try sessionRepo.get(id: s2.id) != nil)
    }

    @Test("delete throws for unknown project")
    func deleteUnknownProject() throws {
        let (projectService, sessionService, _, _) = buildCtx()

        #expect(throws: RockyError.projectNotFound("nonexistent")) {
            try projectService.delete(name: "nonexistent", sessionService: sessionService)
        }
    }

    @Test("delete project with no sessions returns zero count")
    func deleteProjectNoSessions() throws {
        let (projectService, sessionService, projectRepo, _) = buildCtx()
        _ = try projectRepo.create(name: "empty-project", slug: "empty-project")

        let count = try projectService.delete(name: "empty-project", sessionService: sessionService)

        #expect(count == 0)
    }
}
