import Foundation
import SQLiteNIO

public struct Project: Sendable {
    public let id: Int
    public let parentId: Int?
    public let name: String
    public let createdAt: Date

    public init(id: Int, parentId: Int?, name: String, createdAt: Date) {
        self.id = id
        self.parentId = parentId
        self.name = name
        self.createdAt = createdAt
    }

    public init(row: SQLiteRow) throws {
        guard let id = row.column("id")?.integer,
              let name = row.column("name")?.string,
              let createdAtStr = row.column("created_at")?.string else {
            throw RockyCoreError.invalidRow("project")
        }
        self.id = id
        self.parentId = row.column("parent_id")?.integer
        self.name = name
        self.createdAt = try DateFormatter.sqlite.parseOrThrow(createdAtStr)
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

extension DateFormatter {
    static let sqlite: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        f.timeZone = TimeZone(identifier: "UTC")
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    func parseOrThrow(_ string: String) throws -> Date {
        guard let date = date(from: string) else {
            throw RockyCoreError.invalidRow("date parse failed: \(string)")
        }
        return date
    }
}
