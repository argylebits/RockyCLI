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
        let db = try await Database.open()
        defer { Task { try? await db.close() } }

        let projectService = ProjectService(db: db)
        let sessionService = SessionService(db: db)

        if all {
            try await stopAll(projectService: projectService, sessionService: sessionService)
            return
        }

        if let projectName = project {
            try await stopProject(name: projectName, projectService: projectService, sessionService: sessionService)
            return
        }

        // No args — check running timers
        let running = try await sessionService.getRunningWithProjects()

        if running.isEmpty {
            print("No timers currently running.")
            return
        }

        if running.count == 1 {
            let (_, proj) = running[0]
            let stopped = try await sessionService.stop(projectId: proj.id)
            print("Stopped \(proj.name) (\(Formatter.duration(stopped.duration())))")
            return
        }

        // Multiple running — interactive prompt
        print(Table.renderRunningTimers(running))
        print()

        while true {
            print("Stop which? (\(running.indices.map { "\($0 + 1)" }.joined(separator: "/"))/all): ", terminator: "")
            guard let input = readLine()?.trimmingCharacters(in: .whitespaces) else { continue }

            if input == "all" {
                try await stopAll(projectService: projectService, sessionService: sessionService)
                return
            }

            if let num = Int(input), num >= 1, num <= running.count {
                let (_, proj) = running[num - 1]
                let stopped = try await sessionService.stop(projectId: proj.id)
                print("Stopped \(proj.name) (\(Formatter.duration(stopped.duration())))")
                return
            }

            print("Invalid choice. Try again.")
        }
    }

    private func stopProject(name: String, projectService: ProjectService, sessionService: SessionService) async throws {
        guard let proj = try await projectService.getByName(name) else {
            throw CleanExit.message("No project found with name \"\(name)\".")
        }
        let stopped = try await sessionService.stop(projectId: proj.id)
        print("Stopped \(proj.name) (\(Formatter.duration(stopped.duration())))")
    }

    private func stopAll(projectService: ProjectService, sessionService: SessionService) async throws {
        let stopped = try await sessionService.stopAll()
        if stopped.isEmpty {
            print("No timers currently running.")
            return
        }

        var entries: [(name: String, duration: String)] = []
        for session in stopped {
            if let proj = try await projectService.getById(session.projectId) {
                entries.append((proj.name, Formatter.duration(session.duration())))
            }
        }

        let maxName = entries.map(\.name.count).max() ?? 0
        for entry in entries {
            let padded = entry.name.padding(toLength: maxName, withPad: " ", startingAt: 0)
            print("Stopped \(padded)  (\(entry.duration))")
        }
    }
}
