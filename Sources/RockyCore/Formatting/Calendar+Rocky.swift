import Foundation

extension Calendar {

    /// Weekday name from calendar weekday number (1=Sun, 2=Mon, ..., 7=Sat)
    public func weekdayName(_ weekday: Int) -> String {
        guard weekday >= 1, weekday <= weekdaySymbols.count else { return "Unknown" }
        return weekdaySymbols[weekday - 1]
    }

    /// Very short weekday symbols rotated to Monday-first order
    public var mondayFirstVeryShortWeekdaySymbols: [String] {
        let symbols = veryShortStandaloneWeekdaySymbols
        return Array(symbols[1...]) + [symbols[0]]
    }

    /// Abbreviated month name for the given date
    public func monthAbbreviation(for date: Date) -> String {
        let month = component(.month, from: date)
        return shortMonthSymbols[month - 1]
    }
}
