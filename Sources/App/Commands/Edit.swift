import ArgumentParser
import Foundation
import RockyCore

struct Edit: AsyncParsableCommand {
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

    func run() async throws {
        let ctx = try await AppContext.build()
        defer { Task { try? await ctx.close() } }

        if let sessionId = session {
            try await nonInteractive(sessionId: sessionId, ctx: ctx)
        } else if let projectName = project {
            try await interactive(projectName: projectName, ctx: ctx)
        } else {
            throw ValidationError("Provide a project name for interactive mode or --session for non-interactive mode.")
        }
    }

    // MARK: - Non-interactive

    private func nonInteractive(sessionId: Int, ctx: AppContext) async throws {
        let newStart = try start.map { try DateTimeFormat.parse($0) }
        let newStop = try stop.map { try DateTimeFormat.parse($0) }

        let updated = try await ctx.sessionService.editSession(
            id: sessionId,
            newStart: newStart,
            newStop: newStop,
            newDuration: duration
        )

        printSessionSummary(updated)
    }

    // MARK: - Interactive

    private func interactive(projectName: String, ctx: AppContext) async throws {
        guard let proj = try await ctx.projectService.getByName(projectName) else {
            throw ValidationError("No project found with name \"\(projectName)\".")
        }

        let calendar = Calendar.current
        let to = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date()))!
        let from = calendar.date(byAdding: .day, value: -90, to: to)!
        let sessions = try await ctx.sessionService.getSessions(from: from, to: to, projectId: proj.id)

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

        let sessionId = promptForSessionId(sessions: sessions.map(\.0))

        guard let existing = try await ctx.sessionService.getById(sessionId) else {
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

        let field = promptForField(isRunning: existing.isRunning)

        switch field {
        case .start:
            let newStart = promptForDatetime("New value (YYYY-MM-DD HH:MM): ")
            let updated = try await ctx.sessionService.editSession(id: sessionId, newStart: newStart, newStop: nil, newDuration: nil)
            printSessionSummary(updated)
        case .stop:
            let newStop = promptForDatetime("New value (YYYY-MM-DD HH:MM): ")
            let updated = try await ctx.sessionService.editSession(id: sessionId, newStart: nil, newStop: newStop, newDuration: nil)
            printSessionSummary(updated)
        case .duration:
            let newDuration = promptForDuration()
            let updated = try await ctx.sessionService.editSession(id: sessionId, newStart: nil, newStop: nil, newDuration: newDuration)
            printSessionSummary(updated)
        }
    }

    // MARK: - Prompts

    private func promptForSessionId(sessions: [Session]) -> Int {
        let validIds = Set(sessions.map(\.id))
        while true {
            print("Edit which? ", terminator: "")
            guard let input = readLine()?.trimmingCharacters(in: .whitespaces),
                  let id = Int(input) else {
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

    private func promptForField(isRunning: Bool) -> Field {
        while true {
            print("Edit which field? (1/2/3): ", terminator: "")
            guard let input = readLine()?.trimmingCharacters(in: .whitespaces) else { continue }

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

    private func promptForDatetime(_ prompt: String) -> Date {
        while true {
            print(prompt, terminator: "")
            guard let input = readLine()?.trimmingCharacters(in: .whitespaces) else { continue }
            do {
                return try DateTimeFormat.parse(input)
            } catch {
                print("Invalid format. Use YYYY-MM-DD HH:MM (e.g. 2026-03-10 17:30).")
            }
        }
    }

    private func promptForDuration() -> Double {
        while true {
            print("New value (seconds): ", terminator: "")
            guard let input = readLine()?.trimmingCharacters(in: .whitespaces),
                  let seconds = Double(input),
                  seconds > 0 else {
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
