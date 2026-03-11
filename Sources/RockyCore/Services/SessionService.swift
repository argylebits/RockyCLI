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

    public func getById(_ id: Int) async throws -> Session? {
        try await repository.getById(id)
    }

    public func editSession(
        id: Int,
        newStart: Date?,
        newStop: Date?,
        newDuration: TimeInterval?
    ) async throws -> Session {
        // Validate not overdetermined
        if newStart != nil && newStop != nil && newDuration != nil {
            throw RockyCoreError.overdetermined
        }

        // Fetch existing session
        guard let existing = try await repository.getById(id) else {
            throw RockyCoreError.sessionNotFound(id)
        }

        // Validate duration if provided
        if let duration = newDuration, duration <= 0 {
            throw RockyCoreError.durationNotPositive
        }

        // Resolve final start and stop based on flag combinations
        let finalStart: Date
        let finalStop: Date?

        if let start = newStart, let stop = newStop {
            // --start + --stop
            finalStart = start
            finalStop = stop
        } else if let start = newStart, let duration = newDuration {
            // --start + --duration
            finalStart = start
            finalStop = start.addingTimeInterval(duration)
        } else if let stop = newStop, let duration = newDuration {
            // --stop + --duration
            finalStart = stop.addingTimeInterval(-duration)
            finalStop = stop
        } else if let start = newStart {
            // --start only
            finalStart = start
            finalStop = existing.endTime
        } else if let stop = newStop {
            // --stop only
            finalStart = existing.startTime
            finalStop = stop
        } else if let duration = newDuration {
            // --duration only
            finalStart = existing.startTime
            finalStop = existing.startTime.addingTimeInterval(duration)
        } else {
            // Nothing provided — shouldn't happen but return unchanged
            return existing
        }

        // Validate: cannot edit stop of a running session
        if existing.isRunning && finalStop != nil && (newStop != nil || newDuration != nil) {
            throw RockyCoreError.cannotEditRunningSessionStop
        }

        // Validate: start not in future
        if finalStart > Date() {
            throw RockyCoreError.startTimeInFuture
        }

        // Validate: stop must be after start
        if let stop = finalStop, stop <= finalStart {
            throw RockyCoreError.stopBeforeStart
        }

        return try await repository.update(id: id, startTime: finalStart, endTime: finalStop)
    }
}
