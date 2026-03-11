import Testing
import Foundation
@testable import RockyCore

@Suite("DurationFormat")
struct DurationFormatTests {
    @Test("formats zero seconds")
    func zero() {
        #expect(DurationFormat.formatted(0) == "0h 00s")
    }

    @Test("formats seconds under a minute")
    func underMinute() {
        let result = DurationFormat.formatted(30)
        #expect(result.contains("0h"))
        #expect(result.contains("30s"))
    }

    @Test("formats exactly one minute")
    func oneMinute() {
        #expect(DurationFormat.formatted(60) == "0h 01m")
    }

    @Test("formats five minutes with zero-padding")
    func fiveMinutes() {
        #expect(DurationFormat.formatted(300) == "0h 05m")
    }

    @Test("formats 45 minutes")
    func fortyFiveMinutes() {
        #expect(DurationFormat.formatted(2700) == "0h 45m")
    }

    @Test("formats exactly one hour")
    func oneHour() {
        #expect(DurationFormat.formatted(3600) == "1h 00m")
    }

    @Test("formats one hour thirty minutes")
    func oneHourThirty() {
        #expect(DurationFormat.formatted(5400) == "1h 30m")
    }

    @Test("formats two hours thirty minutes")
    func twoHoursThirty() {
        #expect(DurationFormat.formatted(9000) == "2h 30m")
    }

    @Test("formats eleven hours")
    func elevenHours() {
        #expect(DurationFormat.formatted(39600) == "11h 00m")
    }

    @Test("hoursOnly formats as hours")
    func hoursOnly() {
        #expect(DurationFormat.formatted(39600, hoursOnly: true) == "11h")
    }

    @Test("hoursOnly formats large values")
    func hoursOnlyLarge() {
        #expect(DurationFormat.formatted(108000, hoursOnly: true) == "30h")
    }

    @Test("zero-padding applies to single-digit minutes")
    func zeroPaddingSingleDigit() {
        let result = DurationFormat.formatted(3660) // 1h 1m
        #expect(result == "1h 01m")
    }

    @Test("no double-padding on two-digit minutes")
    func noDoublePadding() {
        let result = DurationFormat.formatted(4200) // 1h 10m
        #expect(result == "1h 10m")
    }
}
