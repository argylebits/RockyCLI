import ArgumentParser
import Foundation
import RockyCore

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

        let updated = try ctx.sessionService.editSession(
            id: sessionId,
            newStart: newStart,
            newStop: newStop,
            newDuration: duration
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
        let sessions = try ctx.sessionService.getSessions(from: from, to: to, projectId: proj.id)

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

        guard let existing = try ctx.sessionService.getById(sessionId) else {
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
            let updated = try ctx.sessionService.editSession(id: sessionId, newStart: newStart, newStop: nil, newDuration: nil)
            printSessionSummary(updated)
        case .stop:
            let newStop = try promptForDatetime("New value (YYYY-MM-DD HH:MM): ")
            let updated = try ctx.sessionService.editSession(id: sessionId, newStart: nil, newStop: newStop, newDuration: nil)
            printSessionSummary(updated)
        case .duration:
            let newDuration = try promptForDuration()
            let updated = try ctx.sessionService.editSession(id: sessionId, newStart: nil, newStop: nil, newDuration: newDuration)
        }
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
