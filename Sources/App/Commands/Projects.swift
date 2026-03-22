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

        @OptionGroup var outputOptions: OutputOptions

        func run() throws {
            let ctx = try AppContext.build()
            let result = try execute(ctx: ctx)
            output(result, options: outputOptions)
        }

        @discardableResult
        func execute(ctx: AppContext) throws -> CommandResult {
            let projects = try ctx.projectService.list()
            return .projectList(projects: projects)
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

        @OptionGroup var outputOptions: OutputOptions

        func run() throws {
            let ctx = try AppContext.build()
            let result = try execute(ctx: ctx)
            output(result, options: outputOptions)
        }

        @discardableResult
        func execute(ctx: AppContext) throws -> CommandResult {
            let renamed = try ctx.projectService.rename(oldName: oldName, newName: newName)
            return .projectRenamed(oldName: oldName, newName: renamed.name)
        }
    }
}
