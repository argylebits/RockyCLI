import Foundation

public struct ProjectService: Sendable {
    private let repository: any ProjectRepository

    public init(repository: any ProjectRepository) {
        self.repository = repository
    }

    public func findOrCreate(name: String) async throws -> Project {
        try await repository.findOrCreate(name: name)
    }

    public func getById(_ id: Int) async throws -> Project? {
        try await repository.getById(id)
    }

    public func getByName(_ name: String) async throws -> Project? {
        try await repository.getByName(name)
    }

    public func list() async throws -> [Project] {
        try await repository.list()
    }
}
