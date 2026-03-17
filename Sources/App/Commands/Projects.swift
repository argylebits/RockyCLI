import ArgumentParser
import RockyCore

struct Projects: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "List all projects."
    )

    func run() async throws {
        let ctx = try await AppContext.build()

        let projects = try await ctx.projectService.list()

        if projects.isEmpty {
            output("No projects found.")
            return
        }

        output(Table.renderProjects(projects))
    }
}
