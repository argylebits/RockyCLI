import Foundation

public enum DateTimeFormat {

    // MARK: - Parse Strategies

    /// Parses "YYYY-MM-DD HH:MM" in local timezone
    public static let dateTimeStrategy = Date.ParseStrategy(
        format: "\(year: .defaultDigits)-\(month: .twoDigits)-\(day: .twoDigits) \(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased)):\(minute: .twoDigits)",
        timeZone: .current
    )

    /// Parses "YYYY-MM-DD" in local timezone
    public static let dateStrategy = Date.ParseStrategy(
        format: "\(year: .defaultDigits)-\(month: .twoDigits)-\(day: .twoDigits)",
        timeZone: .current
    )

    // MARK: - Format Styles

    /// Time per system locale, e.g. "17:05" or "5:05 PM"
    public static let time = Date.FormatStyle()
        .hour()
        .minute(.twoDigits)

    /// Abbreviated weekday, e.g. "Mon"
    public static let dayOfWeek = Date.FormatStyle()
        .weekday(.abbreviated)

    /// Weekday with date, e.g. "Tue, Mar 10"
    public static let dateWithDay = Date.FormatStyle()
        .weekday(.abbreviated)
        .day(.twoDigits)
        .month(.abbreviated)

    /// Full weekday with date, e.g. "Tuesday, Mar 10, 2026"
    public static let fullDate = Date.FormatStyle()
        .weekday(.wide)
        .day(.twoDigits)
        .month(.abbreviated)
        .year()

    /// Weekday with date and year, e.g. "Tue, Mar 10, 2026"
    public static let dateWithDayYear = Date.FormatStyle()
        .weekday(.abbreviated)
        .day(.twoDigits)
        .month(.abbreviated)
        .year()

    /// Full month and year, e.g. "March 2026"
    public static let monthYear = Date.FormatStyle()
        .month(.wide)
        .year()

    /// Abbreviated month and year, e.g. "Mar 2026"
    public static let shortMonthYear = Date.FormatStyle()
        .month(.abbreviated)
        .year()

    /// Short date, e.g. "Mar 10"
    public static let shortDate = Date.FormatStyle()
        .day(.twoDigits)
        .month(.abbreviated)

    /// Year only, e.g. "2026"
    public static let year = Date.FormatStyle()
        .year()

    // MARK: - Convenience

    public static func parse(_ string: String) throws -> Date {
        try Date(string, strategy: dateTimeStrategy)
    }

    public static func parseDate(_ string: String) throws -> Date {
        try Date(string, strategy: dateStrategy)
    }

    /// Formats a date range, e.g. "Mon, Mar 02 — Fri, Mar 06, 2026"
    /// The `to` date is treated as exclusive (end of range), so it backs up one day for display.
    public static func periodRange(from: Date, to: Date) -> String {
        let calendar = Calendar.current
        let displayEnd = calendar.date(byAdding: .day, value: -1, to: to) ?? to
        return "\(from.formatted(dateWithDay)) — \(displayEnd.formatted(dateWithDayYear))"
    }
}
