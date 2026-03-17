import ArgumentParser
import RockyCore

struct Projects: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "List all projects."
    )

    func run() throws {
        let ctx = try AppContext.build()

        let projects = try ctx.projectService.list()

        if projects.isEmpty {
            output("No projects found.")
            return
        }

        output(Table.renderProjects(projects))
    }
}
