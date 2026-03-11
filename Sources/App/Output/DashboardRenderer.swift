import Foundation
import RockyCore

enum DashboardRenderer {

    // MARK: - Box Drawing Characters

    private static let dblH: Character = "\u{2550}" // ═
    private static let dblV: Character = "\u{2551}" // ║
    private static let dblTL: Character = "\u{2554}" // ╔
    private static let dblTR: Character = "\u{2557}" // ╗
    private static let dblBL: Character = "\u{255A}" // ╚
    private static let dblBR: Character = "\u{255D}" // ╝

    private static let sngH: Character = "\u{2500}" // ─
    private static let sngV: Character = "\u{2502}" // │
    private static let rndTL: Character = "\u{256D}" // ╭
    private static let rndTR: Character = "\u{256E}" // ╮
    private static let rndBL: Character = "\u{2570}" // ╰
    private static let rndBR: Character = "\u{256F}" // ╯

    // MARK: - Intensity Characters

    private static let intensityNone = "\u{00B7}" // ·
    private static let intensityLight = "\u{2591}" // ░
    private static let intensityMod = "\u{2592}" // ▒
    private static let intensityBusy = "\u{2593}" // ▓
    private static let intensityHeavy = "\u{2588}" // █

    // MARK: - Sparkline Characters

    private static let sparkChars: [Character] = [
        "\u{2581}", "\u{2582}", "\u{2583}", "\u{2584}",
        "\u{2585}", "\u{2586}", "\u{2587}", "\u{2588}",
    ]

    // MARK: - Layout Constants

    private static let outerPad = 2
    private static let innerWidth = 70
    private static let totalWidth = innerWidth + outerPad * 2

    // MARK: - Public Entry Point

    static func render(_ data: DashboardData) -> String {
        var lines: [String] = []

        lines.append("Rocky Dashboard")
        lines.append(outerTopBorder())
        lines.append(emptyOuterLine())

        // Running timers
        lines += renderFullWidget(
            title: "Running",
            content: renderRunningTimersContent(data.runningTimers)
        )
        lines.append(emptyOuterLine())

        // Time summaries
        lines += renderFullWidget(
            title: "Time Summary",
            content: renderTimeSummariesContent(data.timeSummary)
        )
        lines.append(emptyOuterLine())

        // Activity heatmap
        lines += renderFullWidget(
            title: "Activity Heatmap",
            content: renderHeatmapContent(data.heatmap)
        )
        lines.append(emptyOuterLine())

        // Trend sparkline
        lines += renderFullWidget(
            title: "Weekly Trend",
            content: renderSparklineContent(data.sparkline)
        )
        lines.append(emptyOuterLine())

        // Projects
        lines += renderFullWidget(
            title: "Projects This Week",
            content: renderProjectsContent(data.projectDistribution, width: fullContentWidth)
        )
        lines.append(emptyOuterLine())

        // Peak Hours
        lines += renderFullWidget(
            title: "Peak Hours",
            content: renderPeakHoursContent(data.peakHours, width: fullContentWidth)
        )
        lines.append(emptyOuterLine())

        // Streaks & Stats
        lines += renderFullWidget(
            title: "Streaks & Stats",
            content: renderStatsContent(data.stats)
        )
        lines.append(emptyOuterLine())

        lines.append(outerBottomBorder())

        return lines.joined(separator: "\n")
    }

    // MARK: - Outer Border

    private static func outerTopBorder() -> String {
        String(dblTL) + String(repeating: dblH, count: totalWidth) + String(dblTR)
    }

    private static func outerBottomBorder() -> String {
        String(dblBL) + String(repeating: dblH, count: totalWidth) + String(dblBR)
    }

    private static func emptyOuterLine() -> String {
        outerWrap("")
    }

    private static func outerWrap(_ content: String) -> String {
        let padRight = max(0, innerWidth - content.count)
        return String(dblV) + pad(outerPad) + content + pad(padRight) + pad(outerPad) + String(dblV)
    }

    // MARK: - Full Width Widget

    private static let fullBoxInner = innerWidth - 2 // minus │ on each side
    private static let fullContentWidth = fullBoxInner - 4 // minus 2 spaces padding each side

    private static func renderFullWidget(
        title: String, content: [String]
    ) -> [String] {
        var lines: [String] = []
        lines.append(outerWrap(title))
        lines.append(outerWrap(String(rndTL) + String(repeating: sngH, count: fullBoxInner) + String(rndTR)))
        lines.append(outerWrap(String(sngV) + pad(fullBoxInner) + String(sngV)))

        for line in content {
            let linepad = max(0, fullContentWidth - line.count)
            lines.append(outerWrap(
                String(sngV) + pad(2) + line + pad(linepad) + pad(2) + String(sngV)
            ))
        }

        lines.append(outerWrap(String(sngV) + pad(fullBoxInner) + String(sngV)))
        lines.append(outerWrap(String(rndBL) + String(repeating: sngH, count: fullBoxInner) + String(rndBR)))

        return lines
    }

    // MARK: - Running Timers Content

    private static func renderRunningTimersContent(_ timers: [RunningTimer]) -> [String] {
        if timers.isEmpty {
            return ["No timers running."]
        }

        return timers.map { "\u{25B6} \($0.projectName) (\(DurationFormat.formatted($0.duration)))" }
    }

    // MARK: - Time Summaries Content

    private static func renderTimeSummariesContent(_ summary: TimeSummary) -> [String] {
        let weekDiff = summary.weekDifference
        let monthDiff = summary.monthDifference

        // Compute delta duration strings up front to find max width
        let weekDiffStr = weekDiff != 0 ? DurationFormat.formatted(abs(weekDiff)) : ""
        let monthDiffStr = monthDiff != 0 ? DurationFormat.formatted(abs(monthDiff)) : ""
        let maxDiffWidth = max(weekDiffStr.count, monthDiffStr.count)

        let weekStr: String
        if weekDiff != 0 {
            let arrow = weekDiff > 0 ? "\u{2191}" : "\u{2193}"
            weekStr = "  " + arrow + "  " + leftPad(weekDiffStr, maxDiffWidth) + " from last week"
        } else {
            weekStr = ""
        }

        let monthStr: String
        if monthDiff != 0 {
            let arrow = monthDiff > 0 ? "\u{2191}" : "\u{2193}"
            monthStr = "  " + arrow + "  " + leftPad(monthDiffStr, maxDiffWidth) + " from last month"
        } else {
            monthStr = ""
        }

        return [
            "This Week   " + leftPad(DurationFormat.formatted(summary.thisWeek), 8) + weekStr,
            "This Month  " + leftPad(DurationFormat.formatted(summary.thisMonth), 8) + monthStr,
            "This Year   " + leftPad(DurationFormat.formatted(summary.thisYear, hoursOnly: true), 8),
        ]
    }

    // MARK: - Heatmap Content

    private static func renderHeatmapContent(_ heatmap: HeatmapData) -> [String] {
        guard !heatmap.weeks.isEmpty else { return ["No activity data."] }

        let allDurations = heatmap.weeks.flatMap(\.days).filter { !$0.isFuture }.map(\.duration)
        let maxDuration = allDurations.max() ?? 0

        let dayLabels = Calendar.current.mondayFirstVeryShortWeekdaySymbols

        // Month labels — placed into a fixed-width buffer so 3-char
        // abbreviations can naturally span into adjacent column space
        let labelWidth = 3
        let gridWidth = labelWidth + heatmap.weeks.count * 2 - 1
        var monthChars = Array(repeating: Character(" "), count: gridWidth)
        var lastMonth = -1
        for (i, week) in heatmap.weeks.enumerated() {
            let month = Calendar.current.component(.month, from: week.weekStartDate)
            if month != lastMonth {
                let name = Calendar.current.monthAbbreviation(for: week.weekStartDate)
                let pos = labelWidth + i * 2
                for (j, char) in name.enumerated() where pos + j < gridWidth {
                    monthChars[pos + j] = char
                }
                lastMonth = month
            }
        }
        let monthRow = String(monthChars)

        // Divider
        let dividerWidth = labelWidth + heatmap.weeks.count * 2 - 1
        let dividerRow = String(repeating: sngH, count: dividerWidth)

        // Day rows (7 days, Mon-Sun)
        var dayRows: [String] = []
        for dayIndex in 0..<7 {
            var row = dayLabels[dayIndex] + pad(labelWidth - 1)
            for (i, week) in heatmap.weeks.enumerated() {
                let activity = week.days[dayIndex]
                row += intensityChar(duration: activity.duration, max: maxDuration, isFuture: activity.isFuture)
                if i < heatmap.weeks.count - 1 {
                    row += pad(1)
                }
            }
            dayRows.append(row)
        }

        return [monthRow, dividerRow] + dayRows
    }

    private static func intensityChar(duration: TimeInterval, max: TimeInterval, isFuture: Bool) -> String {
        if isFuture { return intensityNone }
        guard max > 0, duration > 0 else { return intensityNone }

        let ratio = duration / max
        switch ratio {
        case ..<0.25: return intensityLight
        case 0.25..<0.50: return intensityMod
        case 0.50..<0.75: return intensityBusy
        default: return intensityHeavy
        }
    }

    // MARK: - Sparkline Content

    private static func renderSparklineContent(_ sparkline: SparklineData) -> [String] {
        guard !sparkline.values.isEmpty else { return ["No trend data."] }

        let values = sparkline.values.map(\.value)
        let maxVal = values.max() ?? 0
        let charsPerWeek = max(1, fullContentWidth / values.count)
        let extraChars = fullContentWidth - charsPerWeek * values.count

        var sparkStr = ""
        for (i, value) in values.enumerated() {
            let char: Character
            if maxVal == 0 || value == 0 {
                char = sparkChars[0]
            } else {
                let index = min(
                    Int((value / maxVal) * Double(sparkChars.count - 1)),
                    sparkChars.count - 1
                )
                char = sparkChars[index]
            }
            let width = charsPerWeek + (i < extraChars ? 1 : 0)
            sparkStr += String(repeating: char, count: width)
        }

        // Month labels placed at the position where each month starts
        var labelChars = Array(repeating: Character(" "), count: fullContentWidth)
        var lastMonth = -1
        var pos = 0
        for (i, point) in sparkline.values.enumerated() {
            let month = Calendar.current.component(.month, from: point.weekStartDate)
            if month != lastMonth {
                let name = Calendar.current.monthAbbreviation(for: point.weekStartDate)
                for (j, char) in name.enumerated() where pos + j < fullContentWidth {
                    labelChars[pos + j] = char
                }
                lastMonth = month
            }
            pos += charsPerWeek + (i < extraChars ? 1 : 0)
        }
        let labelRow = String(labelChars)

        return [sparkStr, labelRow]
    }

    // MARK: - Projects Content

    private static func renderProjectsContent(_ entries: [ProjectDistributionEntry], width: Int) -> [String] {
        guard !entries.isEmpty else { return ["No projects this week."] }

        // Fixed-width segments: " " + dur(7) + " " + pct(4) = 13
        // Remaining: name + " " + bar
        let fixedWidth = 13
        let flexWidth = width - fixedWidth
        // Give name what it needs, capped at half of flex space
        let nameWidth = min(
            entries.map(\.projectName.count).max() ?? 0,
            flexWidth / 2
        )
        let barWidth = flexWidth - nameWidth - 1 // -1 for space between name and bar

        var lines: [String] = []
        for entry in entries {
            let name = String(entry.projectName.prefix(nameWidth))
                .padding(toLength: nameWidth, withPad: " ", startingAt: 0)

            let filledCount = entry.percentage > 0
                ? max(1, Int((entry.percentage / 100) * Double(barWidth)))
                : 0
            let emptyCount = barWidth - filledCount
            let bar = String(repeating: intensityHeavy, count: filledCount)
                + String(repeating: intensityLight, count: emptyCount)

            let dur = leftPad(DurationFormat.formatted(entry.duration), 7)
            let pct = leftPad(String(Int(entry.percentage.rounded())) + "%", 4)

            lines.append(name + " " + bar + " " + dur + " " + pct)
        }

        return lines
    }

    // MARK: - Peak Hours Content

    private static func renderPeakHoursContent(_ peakHours: [Int: TimeInterval], width: Int) -> [String] {
        let maxDuration = peakHours.values.max() ?? 0
        // Each column: "HH " (3) + bar + "  " gap (2) between columns
        // Two columns: 3 + bar + 2 + 3 + bar = width
        // 2*bar + 8 = width → bar = (width - 8) / 2
        let maxBarWidth = max(4, (width - 8) / 2)

        var lines: [String] = []
        for row in 0..<12 {
            let leftHour = row
            let rightHour = row + 12

            let leftBar = hourBar(hour: leftHour, peakHours: peakHours, max: maxDuration, width: maxBarWidth)
            let rightBar = hourBar(hour: rightHour, peakHours: peakHours, max: maxDuration, width: maxBarWidth)

            let left = String(format: "%02d", leftHour) + " " + rightPad(leftBar, maxBarWidth)
            let right = String(format: "%02d", rightHour) + " " + rightBar

            lines.append(left + "  " + right)
        }

        return lines
    }

    private static func hourBar(
        hour: Int, peakHours: [Int: TimeInterval], max maxDuration: TimeInterval, width: Int
    ) -> String {
        guard maxDuration > 0, let duration = peakHours[hour], duration > 0 else { return "" }

        let ratio = duration / maxDuration
        let barLen = max(1, Int(ratio * Double(width)))

        let char: String
        switch ratio {
        case ..<0.25: char = intensityLight
        case 0.25..<0.50: char = intensityMod
        case 0.50..<0.75: char = intensityBusy
        default: char = intensityHeavy
        }

        return String(repeating: char, count: barLen)
    }

    // MARK: - Stats Content

    private static func renderStatsContent(_ stats: DashboardStats) -> [String] {
        // Two columns separated by a gap
        let colWidth = (fullContentWidth - 4) / 2 // 4 chars gap between columns
        let labelWidth = colWidth - 10 // 10 chars for value
        let gap = fullContentWidth - colWidth * 2

        func statLine(_ label: String, _ value: String) -> String {
            rightPad(label, labelWidth) + leftPad(value, 10)
        }

        // Left column
        let streakUnit = stats.currentStreak == 1 ? "day" : "days"
        let longestUnit = stats.longestStreak == 1 ? "day" : "days"

        let left: [String] = [
            statLine("Current streak", "\(stats.currentStreak) \(streakUnit)"),
            statLine("Longest streak", "\(stats.longestStreak) \(longestUnit)"),
            statLine("Sessions (week)", "\(stats.sessionsThisWeek)"),
            statLine("Longest session", stats.longestSession.map { DurationFormat.formatted($0.duration) } ?? "-"),
            statLine("Most active day", stats.mostActiveWeekday.map { Calendar.current.weekdayName($0) } ?? "-"),
        ]

        // Right column
        let right: [String] = [
            statLine("Daily avg (week)", DurationFormat.formatted(stats.dailyAvgWeek)),
            statLine("Avg session", DurationFormat.formatted(stats.averageSessionDuration)),
            statLine("Total hours", DurationFormat.formatted(stats.totalHours, hoursOnly: true)),
            statLine("Best day (week)", stats.bestDayThisWeek.map { Calendar.current.weekdayName($0) } ?? "-"),
            statLine("Top project", stats.topProject ?? "-"),
        ]

        // Combine into rows
        return zip(left, right).map { l, r in
            rightPad(l, colWidth) + pad(gap) + r
        }
    }

    // MARK: - String Utilities

    private static func pad(_ count: Int) -> String {
        String(repeating: " ", count: max(0, count))
    }

    private static func leftPad(_ string: String, _ width: Int) -> String {
        pad(max(0, width - string.count)) + string
    }

    private static func rightPad(_ string: String, _ width: Int) -> String {
        string + pad(max(0, width - string.count))
    }
}
