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
    private static let widgetGap = 2

    // MARK: - Public Entry Point

    static func render(_ data: DashboardData) -> String {
        var lines: [String] = []

        lines.append("Rocky Dashboard")
        lines.append(outerTopBorder())
        lines.append(emptyOuterLine())

        // Running timers
        lines += renderRunningTimers(data.runningTimers)
        lines.append(emptyOuterLine())

        // Time summaries
        lines += renderTimeSummaries(data.timeSummary)
        lines.append(emptyOuterLine())

        // Activity heatmap (full width)
        let heatmapLegend = [intensityNone, " none   ",
                             intensityLight, " light   ",
                             intensityMod, " moderate   ",
                             intensityBusy, " busy   ",
                             intensityHeavy, " heavy"].joined()
        lines += renderFullWidget(
            title: "Activity (last 12 weeks)",
            content: renderHeatmapContent(data.heatmap),
            legend: heatmapLegend
        )
        lines.append(emptyOuterLine())

        // Trend sparkline (full width)
        lines += renderFullWidget(
            title: "Trend (last 12 weeks)",
            content: renderSparklineContent(data.sparkline)
        )
        lines.append(emptyOuterLine())

        // Projects + Peak Hours (side by side)
        let halfContentWidth = ((innerWidth - widgetGap) / 2) - 2 - 4 // minus borders, minus padding
        lines += renderSideBySide(
            leftTitle: "Projects This Week",
            leftContent: renderProjectsContent(data.projectDistribution, width: halfContentWidth),
            rightTitle: "Peak Hours",
            rightContent: renderPeakHoursContent(data.peakHours, width: halfContentWidth)
        )
        lines.append(emptyOuterLine())

        // Streaks & Stats (full width)
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

    private static func renderFullWidget(
        title: String, content: [String], legend: String? = nil
    ) -> [String] {
        let contentWidest = content.map(\.count).max() ?? 0
        let legendWidth = legend?.count ?? 0
        let boxContent = max(contentWidest, legendWidth, 30)
        let boxInner = boxContent + 4 // 2 spaces padding each side

        var lines: [String] = []
        lines.append(outerWrap(title))
        lines.append(outerWrap(String(rndTL) + String(repeating: sngH, count: boxInner) + String(rndTR)))
        lines.append(outerWrap(String(sngV) + pad(boxInner) + String(sngV)))

        for line in content {
            let linepad = max(0, boxContent - line.count)
            lines.append(outerWrap(
                String(sngV) + pad(2) + line + pad(linepad) + pad(2) + String(sngV)
            ))
        }

        lines.append(outerWrap(String(sngV) + pad(boxInner) + String(sngV)))
        lines.append(outerWrap(String(rndBL) + String(repeating: sngH, count: boxInner) + String(rndBR)))

        if let legend {
            lines.append(outerWrap(legend))
        }

        return lines
    }

    // MARK: - Side-by-Side Widgets

    private static func renderSideBySide(
        leftTitle: String, leftContent: [String],
        rightTitle: String, rightContent: [String]
    ) -> [String] {
        let halfWidth = (innerWidth - widgetGap) / 2
        let boxInner = halfWidth - 2 // minus │ on each side
        let contentWidth = boxInner - 4 // minus 2 padding each side

        let maxRows = max(leftContent.count, rightContent.count)

        func widgetLine(_ content: String, width: Int) -> String {
            let linepad = max(0, width - content.count)
            return String(sngV) + pad(2) + content + pad(linepad) + pad(2) + String(sngV)
        }

        func emptyWidget(_ width: Int) -> String {
            String(sngV) + pad(width) + String(sngV)
        }

        let topBorder = String(rndTL) + String(repeating: sngH, count: boxInner) + String(rndTR)
        let bottomBorder = String(rndBL) + String(repeating: sngH, count: boxInner) + String(rndBR)

        var lines: [String] = []

        // Titles
        lines.append(outerWrap(
            rightPad(leftTitle, halfWidth) + pad(widgetGap) + rightTitle
        ))

        // Top borders
        lines.append(outerWrap(
            rightPad(topBorder, halfWidth) + pad(widgetGap) + topBorder
        ))

        // Empty row
        lines.append(outerWrap(
            rightPad(emptyWidget(boxInner), halfWidth) + pad(widgetGap) + emptyWidget(boxInner)
        ))

        // Content rows
        for i in 0..<maxRows {
            let leftLine = i < leftContent.count ? leftContent[i] : ""
            let rightLine = i < rightContent.count ? rightContent[i] : ""
            let left = widgetLine(leftLine, width: contentWidth)
            let right = widgetLine(rightLine, width: contentWidth)
            lines.append(outerWrap(rightPad(left, halfWidth) + pad(widgetGap) + right))
        }

        // Empty row
        lines.append(outerWrap(
            rightPad(emptyWidget(boxInner), halfWidth) + pad(widgetGap) + emptyWidget(boxInner)
        ))

        // Bottom borders
        lines.append(outerWrap(
            rightPad(bottomBorder, halfWidth) + pad(widgetGap) + bottomBorder
        ))

        return lines
    }

    // MARK: - Running Timers

    private static func renderRunningTimers(_ timers: [RunningTimer]) -> [String] {
        if timers.isEmpty {
            return [outerWrap("No timers running.")]
        }

        let list = timers.map { "\($0.projectName) (\(Formatter.duration($0.duration)))" }
            .joined(separator: ", ")

        return [outerWrap("\u{25B6} Running: \(list)")]
    }

    // MARK: - Time Summaries

    private static func renderTimeSummaries(_ summary: TimeSummary) -> [String] {
        let weekDiff = summary.weekDifference
        let weekStr: String
        if weekDiff != 0 {
            let arrow = weekDiff > 0 ? "\u{2191}" : "\u{2193}"
            weekStr = "  \(arrow) \(Formatter.duration(abs(weekDiff))) from last week"
        } else {
            weekStr = ""
        }

        let monthDiff = summary.monthDifference
        let monthStr: String
        if monthDiff != 0 {
            let arrow = monthDiff > 0 ? "\u{2191}" : "\u{2193}"
            monthStr = "  \(arrow) \(Formatter.duration(abs(monthDiff))) from last month"
        } else {
            monthStr = ""
        }

        return [
            outerWrap("This Week   " + leftPad(Formatter.duration(summary.thisWeek), 8) + weekStr),
            outerWrap("This Month  " + leftPad(Formatter.duration(summary.thisMonth), 8) + monthStr),
            outerWrap("This Year   " + leftPad(Formatter.duration(summary.thisYear, hoursOnly: true), 8)),
        ]
    }

    // MARK: - Heatmap Content

    private static func renderHeatmapContent(_ heatmap: HeatmapData) -> [String] {
        guard !heatmap.weeks.isEmpty else { return ["No activity data."] }

        let allDurations = heatmap.weeks.flatMap(\.days).filter { !$0.isFuture }.map(\.duration)
        let maxDuration = allDurations.max() ?? 0

        let dayLabels = Formatter.mondayFirstVeryShortWeekdaySymbols

        // Month labels
        var monthRow = pad(4)
        var lastMonth = -1
        for week in heatmap.weeks {
            let month = Calendar.current.component(.month, from: week.weekStartDate)
            if month != lastMonth {
                let name = Formatter.monthAbbreviation(week.weekStartDate)
                monthRow += name + pad(max(0, 3 - name.count))
                lastMonth = month
            } else {
                monthRow += pad(3)
            }
        }

        // Divider
        let dividerWidth = 4 + heatmap.weeks.count * 3
        let dividerRow = String(repeating: sngH, count: dividerWidth)

        // Week-start date headers
        var dateRow = pad(4)
        for week in heatmap.weeks {
            let day = Formatter.dayOfMonth(week.weekStartDate)
            dateRow += leftPad(String(day), 2) + " "
        }

        // Day rows (7 days, Mon-Sun)
        var dayRows: [String] = []
        for dayIndex in 0..<7 {
            var row = dayLabels[dayIndex] + pad(3)
            for week in heatmap.weeks {
                let activity = week.days[dayIndex]
                row += intensityChar(duration: activity.duration, max: maxDuration, isFuture: activity.isFuture)
                row += pad(2)
            }
            dayRows.append(row)
        }

        return [monthRow, dividerRow, dateRow] + dayRows
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

        var sparkStr = ""
        for value in values {
            if maxVal == 0 || value == 0 {
                sparkStr.append(sparkChars[0])
            } else {
                let index = min(
                    Int((value / maxVal) * Double(sparkChars.count - 1)),
                    sparkChars.count - 1
                )
                sparkStr.append(sparkChars[index])
            }
        }

        let startLabel = Formatter.shortDate(sparkline.values.first!.weekStartDate)
        let endLabel = Formatter.shortDate(sparkline.values.last!.weekStartDate)
        let labelGap = max(1, sparkline.values.count - startLabel.count - endLabel.count)
        let labelRow = startLabel + pad(labelGap) + endLabel

        return [sparkStr, labelRow]
    }

    // MARK: - Projects Content

    private static func renderProjectsContent(_ entries: [ProjectDistributionEntry], width: Int) -> [String] {
        guard !entries.isEmpty else { return ["No projects this week."] }

        // Fixed-width segments: " " + dur(7) + " " + pct(4) = 13
        // Remaining: name + " " + bar
        let fixedWidth = 13
        let flexWidth = width - fixedWidth
        // Split flex between name and bar: give bar at least 6, rest to name
        let barWidth = max(6, flexWidth / 3)
        let nameWidth = min(
            entries.map(\.projectName.count).max() ?? 0,
            flexWidth - barWidth - 1 // -1 for space between name and bar
        )

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

            let dur = leftPad(Formatter.duration(entry.duration), 7)
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
        let labelWidth = 20
        var lines: [String] = []

        let streakUnit = stats.currentStreak == 1 ? "day" : "days"
        lines.append(
            rightPad("Current streak", labelWidth) + leftPad("\(stats.currentStreak) \(streakUnit)", 10)
        )

        let longestUnit = stats.longestStreak == 1 ? "day" : "days"
        lines.append(
            rightPad("Longest streak", labelWidth) + leftPad("\(stats.longestStreak) \(longestUnit)", 10)
        )

        lines.append(
            rightPad("Avg session", labelWidth)
            + leftPad(Formatter.duration(stats.averageSessionDuration), 10)
        )

        if let longest = stats.longestSession {
            let dateStr = Formatter.dayOfWeek(longest.date) + " " + Formatter.shortDate(longest.date)
            lines.append(
                rightPad("Longest session", labelWidth)
                + leftPad(Formatter.duration(longest.duration), 10)
                + "  (\(longest.projectName), \(dateStr))"
            )
        }

        if let weekday = stats.mostActiveWeekday {
            lines.append(
                rightPad("Most active day", labelWidth)
                + leftPad(Formatter.weekdayName(weekday), 10)
            )
        }

        return lines
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
