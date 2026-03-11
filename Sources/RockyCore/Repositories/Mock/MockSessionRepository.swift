import Foundation

public final class MockSessionRepository: SessionRepository, @unchecked Sendable {
    private var sessions: [Session] = []
    private var nextId = 1
    private let projectRepository: ProjectRepository

    public init(projectRepository: ProjectRepository) {
        self.projectRepository = projectRepository
    }

    public func start(projectId: Int) async throws {
        let session = Session(id: nextId, projectId: projectId, startTime: Date(), endTime: nil)
        nextId += 1
        sessions.append(session)
    }

    public func hasRunningSession(projectId: Int) async throws -> Bool {
        sessions.contains { $0.projectId == projectId && $0.isRunning }
    }

    public func stop(projectId: Int) async throws -> Session {
        guard let index = sessions.firstIndex(where: { $0.projectId == projectId && $0.isRunning }) else {
            throw RockyCoreError.noRunningTimers
        }
        let stopped = Session(
            id: sessions[index].id,
            projectId: sessions[index].projectId,
            startTime: sessions[index].startTime,
            endTime: Date()
        )
        sessions[index] = stopped
        return stopped
    }

    public func stopAll() async throws -> [Session] {
        var stopped: [Session] = []
        for (index, session) in sessions.enumerated() where session.isRunning {
            let s = Session(
                id: session.id,
                projectId: session.projectId,
                startTime: session.startTime,
                endTime: Date()
            )
            sessions[index] = s
            stopped.append(s)
        }
        return stopped
    }

    public func getRunning() async throws -> [Session] {
        sessions.filter { $0.isRunning }.sorted { $0.startTime < $1.startTime }
    }

    public func getRunningWithProjects() async throws -> [(Session, Project)] {
        var results: [(Session, Project)] = []
        for session in sessions where session.isRunning {
            if let project = try await projectRepository.getById(session.projectId) {
                results.append((session, project))
            }
        }
        return results.sorted { $0.0.startTime < $1.0.startTime }
    }

    public func insert(projectId: Int, startTime: Date, endTime: Date?) async throws {
        let session = Session(id: nextId, projectId: projectId, startTime: startTime, endTime: endTime)
        nextId += 1
        sessions.append(session)
    }

    public func getById(_ id: Int) async throws -> Session? {
        sessions.first { $0.id == id }
    }

    public func update(id: Int, startTime: Date, endTime: Date?) async throws -> Session {
        guard let index = sessions.firstIndex(where: { $0.id == id }) else {
            throw RockyCoreError.sessionNotFound(id)
        }
        let updated = Session(id: id, projectId: sessions[index].projectId, startTime: startTime, endTime: endTime)
        sessions[index] = updated
        return updated
    }

    public func getSessions(from: Date, to: Date, projectId: Int? = nil) async throws -> [(Session, Project)] {
        var results: [(Session, Project)] = []
        for session in sessions {
            if let projectId, session.projectId != projectId { continue }

            let endTime = session.endTime ?? Date()
            let overlaps = session.startTime < to && endTime > from
            if overlaps {
                if let project = try await projectRepository.getById(session.projectId) {
                    results.append((session, project))
                }
            }
        }
        return results.sorted { $0.0.startTime < $1.0.startTime }
    }
}
