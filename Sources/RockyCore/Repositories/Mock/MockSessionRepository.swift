import Foundation

public final class MockSessionRepository: SessionRepository, @unchecked Sendable {
    private var sessions: [Session] = []
    private var nextId = 1
    private let projectRepository: ProjectRepository

    public init(projectRepository: ProjectRepository) {
        self.projectRepository = projectRepository
    }

    public func create(projectId: Int, startTime: Date, endTime: Date?) throws -> Session {
        let session = Session(id: nextId, projectId: projectId, startTime: startTime, endTime: endTime)
        nextId += 1
        sessions.append(session)
        return session
    }

    public func get(id: Int) throws -> Session? {
        sessions.first { $0.id == id }
    }

    public func list(running: Bool? = nil, from: Date? = nil, to: Date? = nil, projectId: Int? = nil) throws -> [(Session, Project)] {
        var filtered = sessions

        if let running {
            filtered = filtered.filter { running ? $0.isRunning : !$0.isRunning }
        }

        if let from, let to {
            filtered = filtered.filter { session in
                let endTime = session.endTime ?? Date()
                return session.startTime < to && endTime > from
            }
        }

        if let projectId {
            filtered = filtered.filter { $0.projectId == projectId }
        }

        let sorted = filtered.sorted { $0.startTime < $1.startTime }

        return try sorted.compactMap { session in
            guard let project = try projectRepository.get(id: session.projectId) else { return nil }
            return (session, project)
        }
    }

    public func update(id: Int, startTime: Date, endTime: Date?) throws -> Session {
        guard let index = sessions.firstIndex(where: { $0.id == id }) else {
            throw RockyCoreError.sessionNotFound(id)
        }
        let updated = Session(id: id, projectId: sessions[index].projectId, startTime: startTime, endTime: endTime)
        sessions[index] = updated
        return updated
    }
}
