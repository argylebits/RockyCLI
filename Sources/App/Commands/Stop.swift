import ArgumentParser
import Foundation
import RockyCore

struct Stop: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Stop a running timer."
    )

    @Argument(help: "The project name to stop tracking.")
    var project: String?

    @Flag(name: .long, help: "Stop all running timers.")
    var all: Bool = false

    func run() async throws {
        let ctx = try await AppContext.build()

        if all {
            try await stopAll(ctx: ctx)
            return
        }

        if let projectName = project {
            try await stopProject(name: projectName, ctx: ctx)
            return
        }

        // No args — check running timers
        let running = try await ctx.sessionService.getRunningWithProjects()

        if running.isEmpty {
            output("No timers currently running.")
            return
        }

        if running.count == 1 {
            let (_, proj) = running[0]
            let stopped = try await ctx.sessionService.stop(projectId: proj.id)
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
                try await stopAll(ctx: ctx)
                return
            }

            if let num = Int(input), num >= 1, num <= running.count {
                let (_, proj) = running[num - 1]
                let stopped = try await ctx.sessionService.stop(projectId: proj.id)
                output("Stopped \(proj.name) (\(DurationFormat.formatted(stopped.duration())))")
                return
            }

            print("Invalid choice. Try again.")
        }
    }

    private func stopProject(name: String, ctx: AppContext) async throws {
        guard let proj = try await ctx.projectService.getByName(name) else {
            throw ValidationError("No project found with name \"\(name)\".")
        }
        let stopped = try await ctx.sessionService.stop(projectId: proj.id)
        output("Stopped \(proj.name) (\(DurationFormat.formatted(stopped.duration())))")
    }

    private func stopAll(ctx: AppContext) async throws {
        let stopped = try await ctx.sessionService.stopAll()
        if stopped.isEmpty {
            output("No timers currently running.")
            return
        }

        var entries: [(name: String, duration: String)] = []
        for session in stopped {
            if let proj = try await ctx.projectService.getById(session.projectId) {
                entries.append((proj.name, DurationFormat.formatted(session.duration())))
            }
        }

        let maxName = entries.map(\.name.count).max() ?? 0
        let lines = entries.map { entry in
            let padded = entry.name.padding(toLength: maxName, withPad: " ", startingAt: 0)
            return "Stopped \(padded)  (\(entry.duration))"
        }
        output(lines.joined(separator: "\n"))
    }
}
