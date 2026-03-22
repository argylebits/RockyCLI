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
            throw RockyError.invalidRow("projects")
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
