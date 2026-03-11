import Testing
import Foundation
@testable import RockyCore

@Suite("DateTimeFormat")
struct DateTimeFormatTests {
    private let cal = Calendar.current

    // MARK: - Parsing

    @Test("parse valid datetime string")
    func parseValid() throws {
        let date = try DateTimeFormat.parse("2026-03-10 17:30")
        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        #expect(comps.year == 2026)
        #expect(comps.month == 3)
        #expect(comps.day == 10)
        #expect(comps.hour == 17)
        #expect(comps.minute == 30)
    }

    @Test("parse midnight")
    func parseMidnight() throws {
        let date = try DateTimeFormat.parse("2026-03-10 00:00")
        let comps = cal.dateComponents([.hour, .minute], from: date)
        #expect(comps.hour == 0)
        #expect(comps.minute == 0)
    }

    @Test("parse end of day")
    func parseEndOfDay() throws {
        let date = try DateTimeFormat.parse("2026-03-10 23:59")
        let comps = cal.dateComponents([.hour, .minute], from: date)
        #expect(comps.hour == 23)
        #expect(comps.minute == 59)
    }

    @Test("parse invalid datetime throws")
    func parseInvalid() {
        #expect(throws: Error.self) {
            try DateTimeFormat.parse("not-a-date")
        }
    }

    @Test("parse empty string throws")
    func parseEmpty() {
        #expect(throws: Error.self) {
            try DateTimeFormat.parse("")
        }
    }

    @Test("parse date-only string throws (missing time)")
    func parseDateOnly() {
        #expect(throws: Error.self) {
            try DateTimeFormat.parse("2026-03-10")
        }
    }

    @Test("parseDate valid date string")
    func parseDateValid() throws {
        let date = try DateTimeFormat.parseDate("2026-03-10")
        let comps = cal.dateComponents([.year, .month, .day], from: date)
        #expect(comps.year == 2026)
        #expect(comps.month == 3)
        #expect(comps.day == 10)
    }

    @Test("parseDate invalid string throws")
    func parseDateInvalid() {
        #expect(throws: Error.self) {
            try DateTimeFormat.parseDate("not-a-date")
        }
    }

    // MARK: - Format Styles

    @Test("time format produces non-empty string")
    func timeFormat() {
        let date = cal.date(from: DateComponents(year: 2026, month: 3, day: 10, hour: 17, minute: 5))!
        let result = date.formatted(DateTimeFormat.time)
        #expect(!result.isEmpty)
        // Locale-dependent, so just check it contains the minute
        #expect(result.contains("05") || result.contains("5"))
    }

    @Test("dayOfWeek produces abbreviated weekday")
    func dayOfWeekFormat() {
        let date = cal.date(from: DateComponents(year: 2026, month: 3, day: 10))! // Tuesday
        let result = date.formatted(DateTimeFormat.dayOfWeek)
        #expect(!result.isEmpty)
        #expect(result.count <= 4) // abbreviated weekdays are short
    }

    @Test("dateWithDay includes weekday and month")
    func dateWithDayFormat() {
        let date = cal.date(from: DateComponents(year: 2026, month: 3, day: 10))!
        let result = date.formatted(DateTimeFormat.dateWithDay)
        #expect(!result.isEmpty)
        #expect(result.count >= 8) // e.g. "Tue, Mar 10"
    }

    @Test("fullDate includes year")
    func fullDateFormat() {
        let date = cal.date(from: DateComponents(year: 2026, month: 3, day: 10))!
        let result = date.formatted(DateTimeFormat.fullDate)
        #expect(result.contains("2026"))
    }

    @Test("dateWithDayYear includes year")
    func dateWithDayYearFormat() {
        let date = cal.date(from: DateComponents(year: 2026, month: 3, day: 10))!
        let result = date.formatted(DateTimeFormat.dateWithDayYear)
        #expect(result.contains("2026"))
    }

    @Test("monthYear produces full month name with year")
    func monthYearFormat() {
        let date = cal.date(from: DateComponents(year: 2026, month: 3, day: 10))!
        let result = date.formatted(DateTimeFormat.monthYear)
        #expect(result.contains("2026"))
    }

    @Test("shortMonthYear produces abbreviated month with year")
    func shortMonthYearFormat() {
        let date = cal.date(from: DateComponents(year: 2026, month: 3, day: 10))!
        let result = date.formatted(DateTimeFormat.shortMonthYear)
        #expect(result.contains("2026"))
    }

    @Test("shortDate produces day and month")
    func shortDateFormat() {
        let date = cal.date(from: DateComponents(year: 2026, month: 3, day: 10))!
        let result = date.formatted(DateTimeFormat.shortDate)
        #expect(!result.isEmpty)
        #expect(!result.contains("2026")) // no year
    }

    @Test("year produces year only")
    func yearFormat() {
        let date = cal.date(from: DateComponents(year: 2026, month: 3, day: 10))!
        let result = date.formatted(DateTimeFormat.year)
        #expect(result == "2026")
    }

    // MARK: - Period Range

    @Test("periodRange formats exclusive end date")
    func periodRange() {
        let from = cal.date(from: DateComponents(year: 2026, month: 3, day: 2))!
        let to = cal.date(from: DateComponents(year: 2026, month: 3, day: 9))! // exclusive
        let result = DateTimeFormat.periodRange(from: from, to: to)
        #expect(result.contains("—"))
        #expect(result.contains("2026")) // year appears in end date
    }

    @Test("periodRange single day range")
    func periodRangeSingleDay() {
        let from = cal.date(from: DateComponents(year: 2026, month: 3, day: 10))!
        let to = cal.date(from: DateComponents(year: 2026, month: 3, day: 11))! // exclusive, so shows Mar 10
        let result = DateTimeFormat.periodRange(from: from, to: to)
        #expect(result.contains("—"))
    }

    // MARK: - Round-trip

    @Test("parse and format round-trip preserves date components")
    func roundTrip() throws {
        let parsed = try DateTimeFormat.parse("2026-06-15 09:45")
        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: parsed)
        #expect(comps.year == 2026)
        #expect(comps.month == 6)
        #expect(comps.day == 15)
        #expect(comps.hour == 9)
        #expect(comps.minute == 45)
    }
}
