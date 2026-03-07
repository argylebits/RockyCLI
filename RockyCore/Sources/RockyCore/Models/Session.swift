import Foundation

public struct Session: Codable, Sendable {
    public let id: Int
    public let projectId: Int
    public let startTime: Date
    public let endTime: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case projectId = "project_id"
        case startTime = "start_time"
        case endTime = "end_time"
    }

    public init(id: Int, projectId: Int, startTime: Date, endTime: Date?) {
        self.id = id
        self.projectId = projectId
        self.startTime = startTime
        self.endTime = endTime
    }

    public var isRunning: Bool { endTime == nil }

    public func duration(at now: Date = Date()) -> TimeInterval {
        let end = endTime ?? now
        return end.timeIntervalSince(startTime)
    }
}
