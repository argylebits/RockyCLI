import Foundation

public struct Project: Codable, Sendable {
    public let id: Int
    public let parentId: Int?
    public let name: String
    public let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case parentId = "parent_id"
        case name
        case createdAt = "created_at"
    }

    public init(id: Int, parentId: Int?, name: String, createdAt: Date) {
        self.id = id
        self.parentId = parentId
        self.name = name
        self.createdAt = createdAt
    }
}

public enum RockyCoreError: Error, CustomStringConvertible {
    case invalidRow(String)
    case projectNotFound(String)
    case timerAlreadyRunning(String)
    case noRunningTimers

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
        }
    }
}
