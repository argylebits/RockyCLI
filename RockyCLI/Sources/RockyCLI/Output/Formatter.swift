import Foundation

enum Formatter {
    static func duration(_ seconds: TimeInterval, hoursOnly: Bool = false) -> String {
        let dur = Duration.seconds(Int(seconds))

        if hoursOnly {
            return dur.formatted(.units(
                allowed: [.hours],
                width: .narrow,
                zeroValueUnits: .show(length: 1),
                fractionalPart: .hide
            ))
        }

        let totalMinutes = Int(seconds) / 60
        let style: Duration.UnitsFormatStyle
        if totalMinutes > 0 {
            style = Duration.UnitsFormatStyle(
                allowedUnits: [.hours, .minutes],
                width: .narrow,
                zeroValueUnits: .show(length: 1),
                fractionalPart: .hide
            )
        } else {
            style = Duration.UnitsFormatStyle(
                allowedUnits: [.hours, .seconds],
                width: .narrow,
                zeroValueUnits: .show(length: 1),
                fractionalPart: .hide
            )
        }
        return dur.formatted(style)
            .replacingOccurrences(of: #" (\d)([ms])"#, with: " 0$1$2", options: .regularExpression)
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
