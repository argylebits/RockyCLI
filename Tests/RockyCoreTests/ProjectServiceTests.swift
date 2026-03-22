import Testing
import Foundation
@testable import RockyCore

@Suite("ProjectService")
struct ProjectServiceTests {
    @Test("create creates a new project")
    func createNew() throws {
        let repo = MockProjectRepository()
        let service = ProjectService(repository: repo)
        let project = try service.create(name: "acme-corp")
        #expect(project.name == "acme-corp")
        #expect(project.slug == "acme-corp")
        #expect(project.id > 0)
    }

    @Test("create throws when slug already exists")
    func createDuplicate() throws {
        let repo = MockProjectRepository()
        let service = ProjectService(repository: repo)
        _ = try service.create(name: "acme-corp")
        #expect(throws: RockyError.self) {
            try service.create(name: "acme-corp")
        }
    }

    @Test("get resolves name to slug for lookup")
    func getByName() throws {
        let repo = MockProjectRepository()
        let service = ProjectService(repository: repo)
        _ = try service.create(name: "Acme Corp")
        let found = try service.get(name: "ACME CORP")
        #expect(found != nil)
        #expect(found?.name == "Acme Corp")
    }

    @Test("rename updates name and slug via repository")
    func rename() throws {
        let repo = MockProjectRepository()
        let service = ProjectService(repository: repo)
        _ = try repo.create(name: "acme-corp", slug: "acme-corp".slugified)
        let renamed = try service.rename(oldName: "acme-corp", newName: "new-acme")
        #expect(renamed.name == "new-acme")
        #expect(renamed.slug == "new-acme")
    }

    @Test("rename is case-insensitive on old name via slug")
    func renameCaseInsensitive() throws {
        let repo = MockProjectRepository()
        let service = ProjectService(repository: repo)
        _ = try repo.create(name: "Acme-Corp", slug: "Acme-Corp".slugified)
        let renamed = try service.rename(oldName: "ACME-CORP", newName: "new-acme")
        #expect(renamed.name == "new-acme")
    }

    @Test("rename throws when old name not found")
    func renameNotFound() throws {
        let repo = MockProjectRepository()
        let service = ProjectService(repository: repo)
        #expect(throws: RockyError.self) {
            try service.rename(oldName: "ghost", newName: "new-name")
        }
    }

    @Test("rename throws when new name's slug already exists")
    func renameDuplicate() throws {
        let repo = MockProjectRepository()
        let service = ProjectService(repository: repo)
        _ = try repo.create(name: "acme-corp", slug: "acme-corp".slugified)
        _ = try repo.create(name: "existing", slug: "existing".slugified)
        #expect(throws: RockyError.self) {
            try service.rename(oldName: "acme-corp", newName: "existing")
        }
    }

    @Test("rename stores new name exactly as provided")
    func renamePreservesCase() throws {
        let repo = MockProjectRepository()
        let service = ProjectService(repository: repo)
        _ = try repo.create(name: "acme-corp", slug: "acme-corp".slugified)
        let renamed = try service.rename(oldName: "acme-corp", newName: "New-Acme")
        #expect(renamed.name == "New-Acme")
        #expect(renamed.slug == "new-acme")
    }

    @Test("sessions remain linked after rename")
    func renamePreservesSessions() throws {
        let projectRepo = MockProjectRepository()
        let sessionRepo = MockSessionRepository(projectRepository: projectRepo)
        let service = ProjectService(repository: projectRepo)
        let project = try projectRepo.create(name: "acme-corp", slug: "acme-corp".slugified)
        _ = try sessionRepo.create(projectId: project.id, startTime: Date().addingTimeInterval(-7200), endTime: Date().addingTimeInterval(-3600))
        _ = try sessionRepo.create(projectId: project.id, startTime: Date(), endTime: nil)

        let renamed = try service.rename(oldName: "acme-corp", newName: "new-acme")

        let running = try sessionRepo.list(running: true, from: nil, to: nil, projectId: nil)
        #expect(running.count == 1)
        #expect(running[0].0.projectId == renamed.id)

        let sessions = try sessionRepo.list(running: nil, from: nil, to: nil, projectId: renamed.id)
        #expect(sessions.count == 2)
    }
}
