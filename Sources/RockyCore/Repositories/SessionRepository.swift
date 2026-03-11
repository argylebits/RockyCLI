import Foundation

public protocol SessionRepository: Sendable {
    func start(projectId: Int) async throws
    func hasRunningSession(projectId: Int) async throws -> Bool
    func stop(projectId: Int) async throws -> Session
    func stopAll() async throws -> [Session]
    func getRunning() async throws -> [Session]
    func getRunningWithProjects() async throws -> [(Session, Project)]
    func insert(projectId: Int, startTime: Date, endTime: Date?) async throws
    func getSessions(from: Date, to: Date, projectId: Int?) async throws -> [(Session, Project)]
    func getById(_ id: Int) async throws -> Session?
    func update(id: Int, startTime: Date, endTime: Date?) async throws -> Session
}
