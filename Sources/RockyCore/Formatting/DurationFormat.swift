import Foundation

public enum DurationFormat {

    private static let hoursMinutes = Duration.UnitsFormatStyle(
        allowedUnits: [.hours, .minutes],
        width: .narrow,
        zeroValueUnits: .show(length: 1),
        fractionalPart: .hide
    )

    private static let hoursSeconds = Duration.UnitsFormatStyle(
        allowedUnits: [.hours, .seconds],
        width: .narrow,
        zeroValueUnits: .show(length: 1),
        fractionalPart: .hide
    )

    private static let hoursOnly = Duration.UnitsFormatStyle(
        allowedUnits: [.hours],
        width: .narrow,
        zeroValueUnits: .show(length: 1),
        fractionalPart: .hide
    )

    /// Formats seconds as "Xh Ym" with zero-padded minutes, e.g. "2h 30m", "0h 05m", "1h 00m"
    /// When `hoursOnly` is true, formats as "Xh", e.g. "30h"
    public static func formatted(_ seconds: TimeInterval, hoursOnly asHoursOnly: Bool = false) -> String {
        let dur = Duration.seconds(Int(seconds))

        if asHoursOnly {
            return dur.formatted(hoursOnly)
        }

        let totalMinutes = Int(seconds) / 60
        let style = totalMinutes > 0 ? hoursMinutes : hoursSeconds

        return dur.formatted(style)
            .replacingOccurrences(of: #" (\d)([ms])"#, with: " 0$1$2", options: .regularExpression)
    }
}
