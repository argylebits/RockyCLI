import ArgumentParser
import RockyCore

struct Projects: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Manage projects.",
        subcommands: [List.self, Rename.self]
    )

    struct List: ParsableCommand {
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

    struct Rename: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Rename a project."
        )

        @Argument(help: "The current project name.")
        var oldName: String

        @Argument(help: "The new project name.")
        var newName: String

        func run() throws {
            let ctx = try AppContext.build()
            let renamed = try ctx.projectService.rename(oldName: oldName, newName: newName)
            output("Renamed \(oldName) → \(renamed.name)")
        }
    }
}
