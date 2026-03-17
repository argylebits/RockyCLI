import Foundation

public final class MockProjectRepository: ProjectRepository, @unchecked Sendable {
    private var projects: [Project] = []
    private var nextId = 1

    public init() {}

    public func findOrCreate(name: String) throws -> Project {
        if let existing = try getByName(name) {
            return existing
        }
        let project = Project(id: nextId, parentId: nil, name: name, createdAt: Date().addingTimeInterval(Double(nextId)))
        nextId += 1
        projects.append(project)
        return project
    }

    public func getById(_ id: Int) throws -> Project? {
        projects.first { $0.id == id }
    }

    public func getByName(_ name: String) throws -> Project? {
        projects.first { $0.name.lowercased() == name.lowercased() }
    }

    public func list() throws -> [Project] {
        projects.sorted { $0.createdAt < $1.createdAt }
    }
}
