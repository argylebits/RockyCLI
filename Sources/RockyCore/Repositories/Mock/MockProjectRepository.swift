import Foundation

public final class MockProjectRepository: ProjectRepository, @unchecked Sendable {
    private var projects: [Project] = []
    private var nextId = 1

    public init() {}

    public func create(name: String, slug: String) throws -> Project {
        if let _ = try get(slug: slug) {
            throw RockyCoreError.projectAlreadyExists(name)
        }
        let project = Project(id: nextId, parentId: nil, name: name, slug: slug, createdAt: Date().addingTimeInterval(Double(nextId)))
        nextId += 1
        projects.append(project)
        return project
    }

    // Keep findOrCreate for backward compatibility with session tests
    public func findOrCreate(name: String, slug: String) throws -> Project {
        if let existing = try get(slug: slug) {
            return existing
        }
        return try create(name: name, slug: slug)
    }

    public func get(id: Int) throws -> Project? {
        projects.first { $0.id == id }
    }

    public func get(slug: String) throws -> Project? {
        projects.first { $0.slug == slug }
    }

    public func list() throws -> [Project] {
        projects.sorted { $0.createdAt < $1.createdAt }
    }

    public func update(id: Int, name: String, slug: String) throws -> Project {
        guard let index = projects.firstIndex(where: { $0.id == id }) else {
            throw RockyCoreError.projectNotFound(String(id))
        }
        if let existing = try get(slug: slug), existing.id != id {
            throw RockyCoreError.projectAlreadyExists(name)
        }
        let updated = Project(id: id, parentId: projects[index].parentId, name: name, slug: slug, createdAt: projects[index].createdAt)
        projects[index] = updated
        return updated
    }
}
