import Foundation

enum Formatter {
    static func duration(_ seconds: TimeInterval, hoursOnly: Bool = false) -> String {
        let totalMinutes = Int(seconds) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hoursOnly {
            return "\(hours)h"
        }
        return "\(hours)h \(String(format: "%02d", minutes))m"
    }

    static func time(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.timeZone = .current
        return f.string(from: date)
    }

    static func dayOfWeek(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        f.timeZone = .current
        return f.string(from: date)
    }

    static func periodToday() -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE dd MMM yyyy"
        f.timeZone = .current
        return f.string(from: Date())
    }

    static func periodWeek(from: Date, to: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE dd MMM"
        f.timeZone = .current
        let startStr = f.string(from: from)

        let f2 = DateFormatter()
        f2.dateFormat = "EEE dd MMM yyyy"
        f2.timeZone = .current
        let endStr = f2.string(from: Calendar.current.date(byAdding: .day, value: -1, to: to) ?? to)

        return "\(startStr) — \(endStr)"
    }

    static func periodMonth(date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        f.timeZone = .current
        return f.string(from: date)
    }

    static func periodYear(date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy"
        f.timeZone = .current
        return f.string(from: date)
    }

    static func periodRange(from: Date, to: Date) -> String {
        periodWeek(from: from, to: to)
    }

    static func projectCreatedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM yyyy"
        f.timeZone = .current
        return f.string(from: date)
    }
}
