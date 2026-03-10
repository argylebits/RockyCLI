import Foundation

public struct SessionService: Sendable {
    private let repository: any SessionRepository

    public init(repository: any SessionRepository) {
        self.repository = repository
    }

    public func start(projectId: Int) async throws {
        try await repository.start(projectId: projectId)
    }

    public func hasRunningSession(projectId: Int) async throws -> Bool {
        try await repository.hasRunningSession(projectId: projectId)
    }

    public func stop(projectId: Int) async throws -> Session {
        try await repository.stop(projectId: projectId)
    }

    public func stopAll() async throws -> [Session] {
        try await repository.stopAll()
    }

    public func getRunning() async throws -> [Session] {
        try await repository.getRunning()
    }

    public func getRunningWithProjects() async throws -> [(Session, Project)] {
        try await repository.getRunningWithProjects()
    }

    public func insert(projectId: Int, startTime: Date, endTime: Date?) async throws {
        try await repository.insert(projectId: projectId, startTime: startTime, endTime: endTime)
    }

    public func getSessions(from: Date, to: Date, projectId: Int? = nil) async throws -> [(Session, Project)] {
        try await repository.getSessions(from: from, to: to, projectId: projectId)
    }
}
