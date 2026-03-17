import Foundation
import GRDB

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

extension Session: FetchableRecord, TableRecord {
    public static let databaseTableName = "sessions"

    public init(row: Row) throws {
        let startTimeString: String = row["start_time"]
        guard let startTime = Date.fromISO8601(startTimeString) else {
            throw RockyCoreError.invalidRow("sessions")
        }

        let endTime: Date?
        if let endTimeString: String = row["end_time"] {
            guard let parsed = Date.fromISO8601(endTimeString) else {
                throw RockyCoreError.invalidRow("sessions")
            }
            endTime = parsed
        } else {
            endTime = nil
        }

        self.init(
            id: row["id"],
            projectId: row["project_id"],
            startTime: startTime,
            endTime: endTime
        )
    }
}
