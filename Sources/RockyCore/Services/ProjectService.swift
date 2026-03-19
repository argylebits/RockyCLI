import Foundation

public struct ProjectService: Sendable {
    private let repository: any ProjectRepository

    public init(repository: any ProjectRepository) {
        self.repository = repository
    }

    public func create(name: String) throws -> Project {
        try repository.create(name: name, slug: name.slugified)
    }

    public func get(id: Int) throws -> Project? {
        try repository.get(id: id)
    }

    public func get(name: String) throws -> Project? {
        try repository.get(slug: name.slugified)
    }

    public func list() throws -> [Project] {
        try repository.list()
    }

    public func rename(oldName: String, newName: String) throws -> Project {
        guard let project = try repository.get(slug: oldName.slugified) else {
            throw RockyCoreError.projectNotFound(oldName)
        }
        let newSlug = newName.slugified
        if let existing = try repository.get(slug: newSlug), existing.id != project.id {
            throw RockyCoreError.projectAlreadyExists(newName)
        }
        return try repository.update(id: project.id, name: newName, slug: newSlug)
    }
}
