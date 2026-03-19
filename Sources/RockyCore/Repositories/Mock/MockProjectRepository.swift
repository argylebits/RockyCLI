import Foundation

public final class MockProjectRepository: ProjectRepository, @unchecked Sendable {
    private var projects: [Project] = []
    private var nextId = 1

    public init() {}

    public func findOrCreate(name: String, slug: String) throws -> Project {
        if let existing = try getBySlug(slug) {
            return existing
        }
        let project = Project(id: nextId, parentId: nil, name: name, slug: slug, createdAt: Date().addingTimeInterval(Double(nextId)))
        nextId += 1
        projects.append(project)
        return project
    }

    public func getById(_ id: Int) throws -> Project? {
        projects.first { $0.id == id }
    }

    public func getBySlug(_ slug: String) throws -> Project? {
        projects.first { $0.slug == slug }
    }

    public func list() throws -> [Project] {
        projects.sorted { $0.createdAt < $1.createdAt }
    }
}
