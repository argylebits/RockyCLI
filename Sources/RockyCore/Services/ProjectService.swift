import Foundation

public struct ProjectService: Sendable {
    private let repository: any ProjectRepository

    public init(repository: any ProjectRepository) {
        self.repository = repository
    }

    public func findOrCreate(name: String) throws -> Project {
        try repository.findOrCreate(name: name)
    }

    public func getById(_ id: Int) throws -> Project? {
        try repository.getById(id)
    }

    public func getByName(_ name: String) throws -> Project? {
        try repository.getByName(name)
    }

    public func list() throws -> [Project] {
        try repository.list()
    }
}
