import Foundation
import GRDB

public struct Project: Codable, Sendable {
    public let id: Int
    public let parentId: Int?
    public let name: String
    public let slug: String
    public let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case parentId = "parent_id"
        case name
        case slug
        case createdAt = "created_at"
    }

    public init(id: Int, parentId: Int?, name: String, slug: String, createdAt: Date) {
        self.id = id
        self.parentId = parentId
        self.name = name
        self.slug = slug
        self.createdAt = createdAt
    }
}

extension Project: FetchableRecord, TableRecord {
    public static let databaseTableName = "projects"

    public init(row: Row) throws {
        let createdAtString: String = row["created_at"]
        guard let createdAt = Date.fromISO8601(createdAtString) else {
            throw RockyCoreError.invalidRow("projects")
        }
        self.init(
            id: row["id"],
            parentId: row["parent_id"],
            name: row["name"],
            slug: row["slug"],
            createdAt: createdAt
        )
    }
}

public enum RockyCoreError: Error, CustomStringConvertible {
    case invalidRow(String)
    case projectNotFound(String)
    case timerAlreadyRunning(String)
    case noRunningTimers
    case sessionNotFound(Int)
    case cannotEditRunningSessionStop
    case startTimeInFuture
    case stopBeforeStart
    case durationNotPositive
    case overdetermined

    public var description: String {
        switch self {
        case .invalidRow(let table):
            return "Invalid row data in \(table) table"
        case .projectNotFound(let name):
            return "No project found with name \"\(name)\""
        case .timerAlreadyRunning(let name):
            return "Timer already running for \(name)"
        case .noRunningTimers:
            return "No timers currently running."
        case .sessionNotFound(let id):
            return "No session found with ID \(id)."
        case .cannotEditRunningSessionStop:
            return "Cannot edit the stop time of a running session. Stop it first."
        case .startTimeInFuture:
            return "Start time cannot be in the future."
        case .stopBeforeStart:
            return "Stop time must be after start time."
        case .durationNotPositive:
            return "Duration must be positive."
        case .overdetermined:
            return "Cannot specify --start, --stop, and --duration together."
        }
    }
}
