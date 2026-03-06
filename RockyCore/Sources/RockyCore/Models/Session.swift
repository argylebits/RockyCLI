import Foundation
import SQLiteNIO

public struct Session: Sendable {
    public let id: Int
    public let projectId: Int
    public let startTime: Date
    public let endTime: Date?

    public init(id: Int, projectId: Int, startTime: Date, endTime: Date?) {
        self.id = id
        self.projectId = projectId
        self.startTime = startTime
        self.endTime = endTime
    }

    public init(row: SQLiteRow) throws {
        guard let id = row.column("id")?.integer,
              let projectId = row.column("project_id")?.integer,
              let startTimeStr = row.column("start_time")?.string else {
            throw RockyCoreError.invalidRow("session")
        }
        self.id = id
        self.projectId = projectId
        self.startTime = try DateFormatter.sqlite.parseOrThrow(startTimeStr)
        if let endTimeStr = row.column("end_time")?.string {
            self.endTime = try DateFormatter.sqlite.parseOrThrow(endTimeStr)
        } else {
            self.endTime = nil
        }
    }

    public var isRunning: Bool { endTime == nil }

    public func duration(at now: Date = Date()) -> TimeInterval {
        let end = endTime ?? now
        return end.timeIntervalSince(startTime)
    }
}
