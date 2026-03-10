import Foundation
import SQLiteNIO

extension SQLiteRow {
    public func decode<T: Decodable>(_ type: T.Type, prefix: String = "") throws -> T {
        var dict: [String: SQLiteData] = [:]
        for column in columns {
            if prefix.isEmpty {
                dict[column.name] = column.data
            } else if column.name.hasPrefix(prefix) {
                dict[String(column.name.dropFirst(prefix.count))] = column.data
            }
        }
        let jsonData = try JSONEncoder().encode(dict)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: jsonData)
    }
}

extension Date {
    public var sqliteBind: SQLiteData {
        .text(ISO8601DateFormatter().string(from: self))
    }
}
