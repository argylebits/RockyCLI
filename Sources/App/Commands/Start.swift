import ArgumentParser
import RockyCore

struct Start: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Start a timer for a project."
    )

    @Argument(help: "The project name to start tracking.")
    var project: String

    func run() throws {
        let ctx = try AppContext.build()

        let proj = try ctx.projectService.get(name: project)
            ?? ctx.projectService.create(name: project)

        let autoStop = try ConfigFile.getBool("auto-stop", default: true)
        if autoStop, try !ctx.sessionService.list(running: true, projectId: proj.id).isEmpty {
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
