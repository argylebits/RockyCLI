import ArgumentParser
import Foundation
import RockyCore

struct Sessions: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Manage sessions.",
        subcommands: [Start.self, Stop.self, Status.self, Edit.self]
    )

    struct Start: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Start a timer for a project."
        )

        @Argument(help: "The project name to start tracking.")
        var project: String

        func run() throws {
            let ctx = try AppContext.build()
            try execute(ctx: ctx)
        }

        func execute(ctx: AppContext) throws {
            let proj = try ctx.projectService.get(name: project)
                ?? ctx.projectService.create(name: project)

            if ctx.config.autoStop, try !ctx.sessionService.list(running: true, projectId: proj.id).isEmpty {
                throw ValidationError("Timer already running for \(proj.name)")
            }

            try ctx.sessionService.create(projectId: proj.id)

            var message = "Started \(proj.name)"
            let running = try ctx.sessionService.list(running: true)
            if running.count > 1 {
                let names = running.map(\.1.name).joined(separator: ", ")
                message += "\nCurrently running: \(names)"
            }
            output(message)
        }
    }

    struct Stop: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Stop a running timer."
        )

        @Argument(help: "The project name to stop tracking.")
        var project: String?

        @Flag(name: .long, help: "Stop all running timers.")
        var all: Bool = false

        func run() throws {
            let ctx = try AppContext.build()
            try execute(ctx: ctx)
        }

        func execute(ctx: AppContext) throws {
            if all {
                try stopAll(ctx: ctx)
                return
            }

            if let projectName = project {
                try stopProject(name: projectName, ctx: ctx)
                return
            }

            // No args — check running timers
            let running = try ctx.sessionService.list(running: true)

            if running.isEmpty {
                output("No timers currently running.")
                return
            }

            if running.count == 1 {
                let (session, proj) = running[0]
                let stopped = try ctx.sessionService.update(id: session.id, startTime: session.startTime, endTime: Date())
                output("Stopped \(proj.name) (\(DurationFormat.formatted(stopped.duration())))")
                return
            }

            // Multiple running — interactive prompt
            print()
            print(Table.renderRunningTimers(running))
            print()

            while true {
                print("Stop which? (\(running.indices.map { "\($0 + 1)" }.joined(separator: "/"))/all): ", terminator: "")
                guard let line = readLine() else {
                    throw ValidationError("Input cancelled.")
                }
                let input = line.trimmingCharacters(in: .whitespaces)

                if input == "all" {
                    try stopAll(ctx: ctx)
                    return
                }

                if let num = Int(input), num >= 1, num <= running.count {
                    let (session, proj) = running[num - 1]
                    let stopped = try ctx.sessionService.update(id: session.id, startTime: session.startTime, endTime: Date())
                    output("Stopped \(proj.name) (\(DurationFormat.formatted(stopped.duration())))")
                    return
                }

                print("Invalid choice. Try again.")
            }
        }

        private func stopProject(name: String, ctx: AppContext) throws {
            guard let proj = try ctx.projectService.get(name: name) else {
                throw ValidationError("No project found with name \"\(name)\".")
            }
            let running = try ctx.sessionService.list(running: true, projectId: proj.id)
            guard let (session, _) = running.first else {
                throw ValidationError("No timer running for \(proj.name).")
            }
            let stopped = try ctx.sessionService.update(id: session.id, startTime: session.startTime, endTime: Date())
            output("Stopped \(proj.name) (\(DurationFormat.formatted(stopped.duration())))")
        }

        private func stopAll(ctx: AppContext) throws {
            let running = try ctx.sessionService.list(running: true)
            if running.isEmpty {
                output("No timers currently running.")
                return
            }

            let now = Date()
            var entries: [(name: String, duration: String)] = []
            for (session, proj) in running {
                let stopped = try ctx.sessionService.update(id: session.id, startTime: session.startTime, endTime: now)
                entries.append((proj.name, DurationFormat.formatted(stopped.duration())))
            }

            let maxName = entries.map(\.name.count).max() ?? 0
            let lines = entries.map { entry in
                let padded = entry.name.padding(toLength: maxName, withPad: " ", startingAt: 0)
                return "Stopped \(padded)  (\(entry.duration))"
            }
            output(lines.joined(separator: "\n"))
        }
    }

    struct Status: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Show time tracking summary."
        )

        @Flag(name: .long, help: "Show totals for today.")
        var today: Bool = false

        @Flag(name: .long, help: "Show totals by day for the current week.")
        var week: Bool = false

        @Flag(name: .long, help: "Show totals by week for the current month.")
        var month: Bool = false

        @Flag(name: .long, help: "Show totals by month for the current year.")
        var year: Bool = false

        @Option(name: .long, help: "Custom range start (YYYY-MM-DD).")
        var from: String?

        @Option(name: .long, help: "Custom range end (YYYY-MM-DD). Defaults to today.")
        var to: String?

        @Flag(name: .shortAndLong, help: "Show individual sessions with start/stop times.")
        var verbose: Bool = false

        @Option(name: .long, help: "Filter to a single project.")
        var project: String?

        func run() throws {
            let ctx = try AppContext.build()
            try execute(ctx: ctx)
        }

        func execute(ctx: AppContext) throws {
            let calendar = Calendar.current

            // Resolve project filter
            var projectId: Int? = nil
            if let projectName = project {
                guard let proj = try ctx.projectService.get(name: projectName) else {
                    throw ValidationError("No project found with name \"\(projectName)\".")
                }
                projectId = proj.id
            }

            // No time range flags — show current status
            if !today && !week && !month && !year && from == nil {
                let statuses = try ctx.reportService.allProjectsWithStatus()
                output(Table.renderStatus(statuses))
                return
            }

            let now = Date()
            let endOfToday = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!

            if today {
                let (start, _) = dayRange(for: now, calendar: calendar)
                if verbose {
                    let sessions = try ctx.reportService.verboseSessions(from: start, to: endOfToday, projectId: projectId)
                    output(Table.renderVerbose(sessions, period: Date().formatted(DateTimeFormat.fullDate), projectFilter: project))
                } else {
                    let totals = try ctx.reportService.totals(from: start, to: endOfToday, projectId: projectId)
                    output(Table.renderTodayTotals(totals, period: Date().formatted(DateTimeFormat.fullDate)))
                }
                return
            }

            if week {
                let (start, _) = weekRange(for: now, calendar: calendar)
                let period = DateTimeFormat.periodRange(from: start, to: endOfToday)
                if verbose {
                    let sessions = try ctx.reportService.verboseSessions(from: start, to: endOfToday, projectId: projectId)
                    output(Table.renderVerbose(sessions, period: period, projectFilter: project))
                } else {
                    let report = try ctx.reportService.groupedByDay(from: start, to: endOfToday, projectId: projectId)
                    output(Table.renderGrouped(report, period: period, projectFilter: project))
                }
                return
            }

            if month {
                let (start, _) = monthRange(for: now, calendar: calendar)
                let period = now.formatted(DateTimeFormat.monthYear)
                if verbose {
                    let sessions = try ctx.reportService.verboseSessions(from: start, to: endOfToday, projectId: projectId)
                    output(Table.renderVerbose(sessions, period: period, projectFilter: project))
                } else {
                    let report = try ctx.reportService.groupedByWeekOfMonth(from: start, to: endOfToday, projectId: projectId)
                    output(Table.renderGrouped(report, period: period, projectFilter: project))
                }
                return
            }

            if year {
                let (start, _) = yearRange(for: now, calendar: calendar)
                let period = now.formatted(DateTimeFormat.year)
                if verbose {
                    let sessions = try ctx.reportService.verboseSessions(from: start, to: endOfToday, projectId: projectId)
                    output(Table.renderVerbose(sessions, period: period, projectFilter: project))
                } else {
                    let report = try ctx.reportService.groupedByMonth(from: start, to: endOfToday, projectId: projectId)
                    output(Table.renderGrouped(report, period: period, projectFilter: project, hoursOnly: true))
                }
                return
            }

            if let fromStr = from {
                guard let fromDate = parseDate(fromStr) else {
                    throw ValidationError("Invalid date format: \(fromStr). Use YYYY-MM-DD.")
                }
                let toDate: Date
                if let toStr = to {
                    guard let parsed = parseDate(toStr) else {
                        throw ValidationError("Invalid date format: \(toStr). Use YYYY-MM-DD.")
                    }
                    toDate = calendar.date(byAdding: .day, value: 1, to: parsed)!
                } else {
                    let (_, endOfToday) = dayRange(for: now, calendar: calendar)
                    toDate = endOfToday
                }

                let days = calendar.dateComponents([.day], from: fromDate, to: toDate).day ?? 0
                let period = DateTimeFormat.periodRange(from: fromDate, to: toDate)

                if verbose {
                    let sessions = try ctx.reportService.verboseSessions(from: fromDate, to: toDate, projectId: projectId)
                    output(Table.renderVerbose(sessions, period: period, projectFilter: project))
                } else if days <= 7 {
                    let report = try ctx.reportService.groupedByDay(from: fromDate, to: toDate, projectId: projectId)
                    output(Table.renderGrouped(report, period: period, projectFilter: project))
                } else if days <= 60 {
                    let report = try ctx.reportService.groupedByWeek(from: fromDate, to: toDate, projectId: projectId)
                    output(Table.renderGrouped(report, period: period, projectFilter: project))
                } else {
                    let report = try ctx.reportService.groupedByMonth(from: fromDate, to: toDate, projectId: projectId)
                    output(Table.renderGrouped(report, period: period, projectFilter: project, hoursOnly: true))
                }
            }
        }

        // MARK: - Date helpers

        private func parseDate(_ string: String) -> Date? {
            try? DateTimeFormat.parseDate(string)
        }

        private func dayRange(for date: Date, calendar: Calendar) -> (Date, Date) {
            let start = calendar.startOfDay(for: date)
            let end = calendar.date(byAdding: .day, value: 1, to: start)!
            return (start, end)
        }

        private func weekRange(for date: Date, calendar: Calendar) -> (Date, Date) {
            var cal = calendar
            cal.firstWeekday = 2 // Monday
            let interval = cal.dateInterval(of: .weekOfYear, for: date)!
            return (interval.start, interval.end)
        }

        private func monthRange(for date: Date, calendar: Calendar) -> (Date, Date) {
            let components = calendar.dateComponents([.year, .month], from: date)
            let start = calendar.date(from: components)!
            let end = calendar.date(byAdding: .month, value: 1, to: start)!
            return (start, end)
        }

        private func yearRange(for date: Date, calendar: Calendar) -> (Date, Date) {
            let components = calendar.dateComponents([.year], from: date)
            let start = calendar.date(from: components)!
            let end = calendar.date(byAdding: .year, value: 1, to: start)!
            return (start, end)
        }
    }

    struct Edit: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Edit the start, stop, or duration of a session."
        )

        @Argument(help: "The project name to edit sessions for.")
        var project: String?

        @Option(name: .long, help: "Session ID (shown in --verbose output).")
        var session: Int?

        @Option(name: .long, help: "New start time (YYYY-MM-DD HH:MM).")
        var start: String?

        @Option(name: .long, help: "New stop time (YYYY-MM-DD HH:MM).")
        var stop: String?

        @Option(name: .long, help: "Duration in seconds.")
        var duration: Double?

        func run() throws {
            let ctx = try AppContext.build()
            try execute(ctx: ctx)
        }

        func execute(ctx: AppContext) throws {
            if let sessionId = session {
                try nonInteractive(sessionId: sessionId, ctx: ctx)
            } else if let projectName = project {
                try interactive(projectName: projectName, ctx: ctx)
            } else {
                throw ValidationError("Provide a project name for interactive mode or --session for non-interactive mode.")
            }
        }

        // MARK: - Non-interactive

        private func nonInteractive(sessionId: Int, ctx: AppContext) throws {
            let newStart = try start.map { try DateTimeFormat.parse($0) }
            let newStop = try stop.map { try DateTimeFormat.parse($0) }

            let updated = try resolveAndUpdate(
                sessionId: sessionId,
                newStart: newStart,
                newStop: newStop,
                newDuration: duration,
                ctx: ctx
            )

            printSessionSummary(updated)
        }

        // MARK: - Interactive

        private func interactive(projectName: String, ctx: AppContext) throws {
            guard let proj = try ctx.projectService.get(name: projectName) else {
                throw ValidationError("No project found with name \"\(projectName)\".")
            }

            let calendar = Calendar.current
            let to = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date()))!
            let from = calendar.date(byAdding: .day, value: -90, to: to)!
            let sessions = try ctx.sessionService.list(from: from, to: to, projectId: proj.id)

            if sessions.isEmpty {
                output("No sessions found for \(proj.name).")
                return
            }

            let verboseRows = sessions.map { session, project in
                VerboseSessionRow(session: session, projectName: project.name)
            }
            let period = DateTimeFormat.periodRange(from: from, to: to)
            print()
            print(Table.renderVerbose(verboseRows, period: period, projectFilter: proj.name))
            print()

            let sessionId = try promptForSessionId(sessions: sessions.map(\.0))

            guard let existing = try ctx.sessionService.get(id: sessionId) else {
                throw ValidationError("No session found with ID \(sessionId).")
            }

            let startStr = existing.startTime.formatted(DateTimeFormat.time)
            let stopStr = existing.isRunning ? "running" : existing.endTime!.formatted(DateTimeFormat.time)
            let durStr = DurationFormat.formatted(existing.duration())

            print()
            print("  \(existing.startTime.formatted(DateTimeFormat.dateWithDay))    \(startStr) — \(stopStr)    \(durStr)")
            print()
            print("  1. Start    (\(startStr))")
            print("  2. Stop     (\(stopStr))")
            print("  3. Duration (\(durStr))")
            print()

            let field = try promptForField(isRunning: existing.isRunning)

            switch field {
            case .start:
                let newStart = try promptForDatetime("New value (YYYY-MM-DD HH:MM): ")
                let updated = try resolveAndUpdate(sessionId: sessionId, newStart: newStart, newStop: nil, newDuration: nil, ctx: ctx)
                printSessionSummary(updated)
            case .stop:
                let newStop = try promptForDatetime("New value (YYYY-MM-DD HH:MM): ")
                let updated = try resolveAndUpdate(sessionId: sessionId, newStart: nil, newStop: newStop, newDuration: nil, ctx: ctx)
                printSessionSummary(updated)
            case .duration:
                let newDuration = try promptForDuration()
                let updated = try resolveAndUpdate(sessionId: sessionId, newStart: nil, newStop: nil, newDuration: newDuration, ctx: ctx)
                printSessionSummary(updated)
            }
        }

        // MARK: - Flag resolution

        private func resolveAndUpdate(
            sessionId: Int,
            newStart: Date?,
            newStop: Date?,
            newDuration: TimeInterval?,
            ctx: AppContext
        ) throws -> Session {
            // Validate not overdetermined
            if newStart != nil && newStop != nil && newDuration != nil {
                throw RockyCoreError.overdetermined
            }

            // Fetch existing session
            guard let existing = try ctx.sessionService.get(id: sessionId) else {
                throw RockyCoreError.sessionNotFound(sessionId)
            }

            // Validate duration if provided
            if let duration = newDuration, duration <= 0 {
                throw RockyCoreError.durationNotPositive
            }

            // Resolve final start and stop based on flag combinations
            let finalStart: Date
            let finalStop: Date?

            if let start = newStart, let stop = newStop {
                finalStart = start
                finalStop = stop
            } else if let start = newStart, let duration = newDuration {
                finalStart = start
                finalStop = start.addingTimeInterval(duration)
            } else if let stop = newStop, let duration = newDuration {
                finalStart = stop.addingTimeInterval(-duration)
                finalStop = stop
            } else if let start = newStart {
                finalStart = start
                finalStop = existing.endTime
            } else if let stop = newStop {
                finalStart = existing.startTime
                finalStop = stop
            } else if let duration = newDuration {
                finalStart = existing.startTime
                finalStop = existing.startTime.addingTimeInterval(duration)
            } else {
                return existing
            }

            // Validate: cannot edit stop of a running session
            if existing.isRunning && finalStop != nil && (newStop != nil || newDuration != nil) {
                throw RockyCoreError.cannotEditRunningSessionStop
            }

            // Validate: start not in future
            if finalStart > Date() {
                throw RockyCoreError.startTimeInFuture
            }

            // Validate: stop must be after start
            if let stop = finalStop, stop <= finalStart {
                throw RockyCoreError.stopBeforeStart
            }

            return try ctx.sessionService.update(id: sessionId, startTime: finalStart, endTime: finalStop)
        }

        // MARK: - Prompts

        private func promptForSessionId(sessions: [Session]) throws -> Int {
            let validIds = Set(sessions.map(\.id))
            while true {
                print("Edit which? ", terminator: "")
                guard let line = readLine() else {
                    throw ValidationError("Input cancelled.")
                }
                let input = line.trimmingCharacters(in: .whitespaces)
                guard let id = Int(input) else {
                    print("Invalid input. Enter a session ID.")
                    continue
                }
                if validIds.contains(id) {
                    return id
                }
                print("No session with ID \(id). Try again.")
            }
        }

        private enum Field { case start, stop, duration }

        private func promptForField(isRunning: Bool) throws -> Field {
            while true {
                print("Edit which field? (1/2/3): ", terminator: "")
                guard let line = readLine() else {
                    throw ValidationError("Input cancelled.")
                }
                let input = line.trimmingCharacters(in: .whitespaces)

                switch input {
                case "1": return .start
                case "2":
                    if isRunning {
                        print("Cannot edit stop time of a running session. Stop it first.")
                        continue
                    }
                    return .stop
                case "3":
                    if isRunning {
                        print("Cannot edit duration of a running session. Stop it first.")
                        continue
                    }
                    return .duration
                default:
                    print("Invalid choice. Enter 1, 2, or 3.")
                }
            }
        }

        private func promptForDatetime(_ prompt: String) throws -> Date {
            while true {
                print(prompt, terminator: "")
                guard let line = readLine() else {
                    throw ValidationError("Input cancelled.")
                }
                let input = line.trimmingCharacters(in: .whitespaces)
                do {
                    return try DateTimeFormat.parse(input)
                } catch {
                    print("Invalid format. Use YYYY-MM-DD HH:MM (e.g. 2026-03-10 17:30).")
                }
            }
        }

        private func promptForDuration() throws -> Double {
            while true {
                print("New value (seconds): ", terminator: "")
                guard let line = readLine() else {
                    throw ValidationError("Input cancelled.")
                }
                let input = line.trimmingCharacters(in: .whitespaces)
                guard let seconds = Double(input), seconds > 0 else {
                    print("Invalid duration. Enter a positive number of seconds.")
                    continue
                }
                return seconds
            }
        }

        // MARK: - Output

        private func printSessionSummary(_ session: Session) {
            let startStr = session.startTime.formatted(DateTimeFormat.time)
            let stopStr = session.isRunning ? "running" : session.endTime!.formatted(DateTimeFormat.time)
            let durStr = DurationFormat.formatted(session.duration())
            output("Updated: \(session.startTime.formatted(DateTimeFormat.dateWithDay))  \(startStr) — \(stopStr)  (\(durStr))")
        }
    }
}
