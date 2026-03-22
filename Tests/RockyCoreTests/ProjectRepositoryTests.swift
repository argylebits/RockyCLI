import Testing
import Foundation
@testable import RockyCore

@Suite("MockProjectRepository")
struct MockProjectRepositoryTests {
    @Test("create inserts a new project")
    func createProject() throws {
        let repo = MockProjectRepository()
        let project = try repo.create(name: "acme-corp", slug: "acme-corp".slugified)
        #expect(project.name == "acme-corp")
        #expect(project.slug == "acme-corp")
        #expect(project.id > 0)
        #expect(project.parentId == nil)
    }

    @Test("create throws when slug already exists")
    func createDuplicateSlug() throws {
        let repo = MockProjectRepository()
        _ = try repo.create(name: "acme-corp", slug: "acme-corp".slugified)
        #expect(throws: RockyError.self) {
            try repo.create(name: "ACME-CORP", slug: "ACME-CORP".slugified)
        }
    }

    @Test("get by slug returns project by exact match")
    func getBySlug() throws {
        let repo = MockProjectRepository()
        _ = try repo.create(name: "Acme-Corp", slug: "Acme-Corp".slugified)
        let found = try repo.get(slug: "acme-corp")
        #expect(found != nil)
        #expect(found?.name == "Acme-Corp")
    }

    @Test("get by slug returns nil for unknown slug")
    func getBySlugUnknown() throws {
        let repo = MockProjectRepository()
        let found = try repo.get(slug: "nonexistent")
        #expect(found == nil)
    }

    @Test("get by id returns correct project")
    func getById() throws {
        let repo = MockProjectRepository()
        let created = try repo.create(name: "test-project", slug: "test-project".slugified)
        let found = try repo.get(id: created.id)
        #expect(found != nil)
        #expect(found?.name == "test-project")
    }

    @Test("get by id returns nil for unknown id")
    func getByIdUnknown() throws {
        let repo = MockProjectRepository()
        let found = try repo.get(id: 999)
        #expect(found == nil)
    }

    @Test("list returns all projects")
    func listProjects() throws {
        let repo = MockProjectRepository()
        _ = try repo.create(name: "alpha", slug: "alpha".slugified)
        _ = try repo.create(name: "beta", slug: "beta".slugified)
        _ = try repo.create(name: "gamma", slug: "gamma".slugified)
        let projects = try repo.list()
        #expect(projects.count == 3)
    }

    @Test("list returns projects in creation order")
    func listOrder() throws {
        let repo = MockProjectRepository()
        _ = try repo.create(name: "charlie", slug: "charlie".slugified)
        _ = try repo.create(name: "alpha", slug: "alpha".slugified)
        _ = try repo.create(name: "bravo", slug: "bravo".slugified)
        let projects = try repo.list()
        #expect(projects[0].name == "charlie")
        #expect(projects[1].name == "alpha")
        #expect(projects[2].name == "bravo")
    }

    @Test("update changes project name and slug")
    func updateNameAndSlug() throws {
        let repo = MockProjectRepository()
        let project = try repo.create(name: "acme-corp", slug: "acme-corp".slugified)
        let updated = try repo.update(id: project.id, name: "new-acme", slug: "new-acme".slugified)
        #expect(updated.name == "new-acme")
        #expect(updated.slug == "new-acme")
        let found = try repo.get(slug: "new-acme")
        #expect(found != nil)
        let old = try repo.get(slug: "acme-corp")
        #expect(old == nil)
    }

    @Test("update throws for unknown id")
    func updateUnknownId() throws {
        let repo = MockProjectRepository()
        #expect(throws: RockyError.self) {
            try repo.update(id: 999, name: "new-name", slug: "new-name".slugified)
        }
    }

    @Test("update throws when new slug already exists")
    func updateDuplicateSlug() throws {
        let repo = MockProjectRepository()
        let project = try repo.create(name: "acme-corp", slug: "acme-corp".slugified)
        _ = try repo.create(name: "existing", slug: "existing".slugified)
        #expect(throws: RockyError.self) {
            try repo.update(id: project.id, name: "existing", slug: "existing".slugified)
        }
    }

    @Test("update preserves project id")
    func updatePreservesId() throws {
        let repo = MockProjectRepository()
        let original = try repo.create(name: "acme-corp", slug: "acme-corp".slugified)
        let updated = try repo.update(id: original.id, name: "new-acme", slug: "new-acme".slugified)
        #expect(updated.id == original.id)
    }

    @Test("update stores new name exactly as provided")
    func updatePreservesCase() throws {
        let repo = MockProjectRepository()
        let project = try repo.create(name: "acme-corp", slug: "acme-corp".slugified)
        let updated = try repo.update(id: project.id, name: "New-Acme", slug: "New-Acme".slugified)
        #expect(updated.name == "New-Acme")
        #expect(updated.slug == "new-acme")
    }
}
