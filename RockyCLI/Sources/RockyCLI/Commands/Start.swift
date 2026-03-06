import ArgumentParser
import RockyCore

struct Start: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Start a timer for a project."
    )

    @Argument(help: "The project name to start tracking.")
    var project: String

    func run() async throws {
        let db = try await Database.open()
        defer { Task { try? await db.close() } }

        let projectService = ProjectService(db: db)
        let sessionService = SessionService(db: db)

        let proj = try await projectService.findOrCreate(name: project)

        if try await sessionService.hasRunningSession(projectId: proj.id) {
            throw CleanExit.message("Timer already running for \(proj.name)")
        }

        try await sessionService.start(projectId: proj.id)
        print("Started \(proj.name)")

        let running = try await sessionService.getRunningWithProjects()
        if running.count > 1 {
            let names = running.map(\.1.name).joined(separator: ", ")
            print("Currently running: \(names)")
        }
    }
}
