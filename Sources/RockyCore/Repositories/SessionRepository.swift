import Foundation

public protocol SessionRepository: Sendable {
    func start(projectId: Int) throws
    func hasRunningSession(projectId: Int) throws -> Bool
    func stop(projectId: Int) throws -> Session
    func stopAll() throws -> [Session]
    func getRunning() throws -> [Session]
    func getRunningWithProjects() throws -> [(Session, Project)]
    func insert(projectId: Int, startTime: Date, endTime: Date?) throws
    func getSessions(from: Date, to: Date, projectId: Int?) throws -> [(Session, Project)]
    func getById(_ id: Int) throws -> Session?
    func update(id: Int, startTime: Date, endTime: Date?) throws -> Session
}
