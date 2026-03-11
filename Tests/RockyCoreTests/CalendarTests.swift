import Testing
import Foundation
@testable import RockyCore

@Suite("Calendar+Rocky")
struct CalendarRockyTests {
    private let cal = Calendar.current

    @Test("weekdayName returns correct name for Sunday (1)")
    func weekdaySunday() {
        #expect(cal.weekdayName(1) == "Sunday")
    }

    @Test("weekdayName returns correct name for Monday (2)")
    func weekdayMonday() {
        #expect(cal.weekdayName(2) == "Monday")
    }

    @Test("weekdayName returns correct name for Saturday (7)")
    func weekdaySaturday() {
        #expect(cal.weekdayName(7) == "Saturday")
    }

    @Test("weekdayName returns Unknown for invalid weekday 0")
    func weekdayInvalidZero() {
        #expect(cal.weekdayName(0) == "Unknown")
    }

    @Test("weekdayName returns Unknown for invalid weekday 8")
    func weekdayInvalidEight() {
        #expect(cal.weekdayName(8) == "Unknown")
    }

    @Test("mondayFirstVeryShortWeekdaySymbols has 7 elements")
    func mondayFirstCount() {
        #expect(cal.mondayFirstVeryShortWeekdaySymbols.count == 7)
    }

    @Test("mondayFirstVeryShortWeekdaySymbols starts with Monday")
    func mondayFirstStartsWithMonday() {
        let symbols = cal.mondayFirstVeryShortWeekdaySymbols
        let mondaySymbol = cal.veryShortStandaloneWeekdaySymbols[1] // index 1 = Monday
        #expect(symbols[0] == mondaySymbol)
    }

    @Test("mondayFirstVeryShortWeekdaySymbols ends with Sunday")
    func mondayFirstEndsWithSunday() {
        let symbols = cal.mondayFirstVeryShortWeekdaySymbols
        let sundaySymbol = cal.veryShortStandaloneWeekdaySymbols[0] // index 0 = Sunday
        #expect(symbols[6] == sundaySymbol)
    }

    @Test("monthAbbreviation returns correct month")
    func monthAbbreviationMarch() {
        let date = cal.date(from: DateComponents(year: 2026, month: 3, day: 10))!
        #expect(cal.monthAbbreviation(for: date) == "Mar")
    }

    @Test("monthAbbreviation for January")
    func monthAbbreviationJanuary() {
        let date = cal.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        #expect(cal.monthAbbreviation(for: date) == "Jan")
    }

    @Test("monthAbbreviation for December")
    func monthAbbreviationDecember() {
        let date = cal.date(from: DateComponents(year: 2026, month: 12, day: 25))!
        #expect(cal.monthAbbreviation(for: date) == "Dec")
    }
}
