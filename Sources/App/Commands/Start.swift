import ArgumentParser
import RockyCore

struct Start: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Start a timer for a project."
    )

    @Argument(help: "The project name to start tracking.")
    var project: String

    func run() async throws {
        let ctx = try await AppContext.build()

        let proj = try await ctx.projectService.findOrCreate(name: project)

        let autoStop = try ConfigFile.getBool("auto-stop", default: true)
        if autoStop, try await ctx.sessionService.hasRunningSession(projectId: proj.id) {
            throw ValidationError("Timer already running for \(proj.name)")
        }

        try await ctx.sessionService.start(projectId: proj.id)

        var message = "Started \(proj.name)"
        let running = try await ctx.sessionService.getRunningWithProjects()
        if running.count > 1 {
            let names = running.map(\.1.name).joined(separator: ", ")
            message += "\nCurrently running: \(names)"
        }
        output(message)
    }
}
