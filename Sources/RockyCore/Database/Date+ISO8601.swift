import Foundation

extension Date {
    /// Formats as ISO8601 with Z suffix, matching Rocky's stored date format.
    public var iso8601String: String {
        ISO8601DateFormatter().string(from: self)
    }

    /// Parses an ISO8601 string with Z suffix into a Date.
    public static func fromISO8601(_ string: String) -> Date? {
        ISO8601DateFormatter().date(from: string)
    }
}
