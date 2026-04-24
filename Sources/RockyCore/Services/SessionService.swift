import Foundation

public struct SessionService: Sendable {
    private let repository: any SessionRepository

    public init(repository: any SessionRepository) {
        self.repository = repository
    }

    @discardableResult
    public func create(projectId: Int) throws -> Session {
        try repository.create(projectId: projectId, startTime: Date(), endTime: nil)
    }

    public func get(id: Int) throws -> Session? {
        try repository.get(id: id)
    }

    public func list(running: Bool? = nil, from: Date? = nil, to: Date? = nil, projectId: Int? = nil) throws -> [(Session, Project)] {
        try repository.list(running: running, from: from, to: to, projectId: projectId)
    }

    public func update(id: Int, startTime: Date, endTime: Date?) throws -> Session {
        try repository.update(id: id, startTime: startTime, endTime: endTime)
    }

    public func delete(id: Int) throws {
        try repository.delete(id: id)
    }

    @discardableResult
    public func deleteAll(projectId: Int) throws -> Int {
        try repository.deleteAll(projectId: projectId)
    }
}
