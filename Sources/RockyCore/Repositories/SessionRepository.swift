import Foundation

public protocol SessionRepository: Sendable {
    func create(projectId: Int, startTime: Date, endTime: Date?) throws -> Session
    func get(id: Int) throws -> Session?
    func list(running: Bool?, from: Date?, to: Date?, projectId: Int?) throws -> [(Session, Project)]
    func update(id: Int, startTime: Date, endTime: Date?) throws -> Session
}
