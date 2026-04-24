import ArgumentParser
import RockyCore

struct Projects: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Manage projects.",
        subcommands: [List.self, Rename.self, Delete.self]
    )

    struct List: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "List all projects."
        )

        @OptionGroup var outputOptions: OutputOptions

        func run() throws {
            do {
                let ctx = try AppContext.build()
                let result = try execute(ctx: ctx)
                output(result, options: outputOptions)
            } catch let error as RockyError {
                outputError(error, options: outputOptions)
                throw ExitCode.failure
            }
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
            do {
                let ctx = try AppContext.build()
                let result = try execute(ctx: ctx)
                output(result, options: outputOptions)
            } catch let error as RockyError {
                outputError(error, options: outputOptions)
                throw ExitCode.failure
            }
        }

        @discardableResult
        func execute(ctx: AppContext) throws -> CommandResult {
            let renamed = try ctx.projectService.rename(oldName: oldName, newName: newName)
            return .projectRenamed(oldName: oldName, project: renamed)
        }
    }

    struct Delete: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Delete a project and all its sessions."
        )

        @Argument(help: "The project name to delete.")
        var name: String?

        @Flag(name: .long, help: "Skip confirmation prompt.")
        var confirm: Bool = false

        @OptionGroup var outputOptions: OutputOptions

        func run() throws {
            do {
                let ctx = try AppContext.build()
                let result = try execute(ctx: ctx)
                output(result, options: outputOptions)
            } catch let error as RockyError {
                outputError(error, options: outputOptions)
                throw ExitCode.failure
            }
        }

        @discardableResult
        func execute(ctx: AppContext) throws -> CommandResult {
            let projectName: String
            if let name {
                projectName = name
            } else {
                projectName = try interactive(ctx: ctx)
            }

            guard let project = try ctx.projectService.get(name: projectName) else {
                throw RockyError.projectNotFound(projectName)
            }

            let sessions = try ctx.sessionService.list(projectId: project.id)
            let sessionCount = sessions.count

            if !confirm {
                print()
                print("Delete project \"\(project.name)\" and \(sessionCount) sessions? (y/N): ", terminator: "")
                guard let line = readLine() else {
                    throw RockyError.sessionInputCancelled
                }
                let input = line.trimmingCharacters(in: .whitespaces).lowercased()
                if input != "y" && input != "yes" {
                    return .message("Cancelled.")
                }
            }

            let deletedCount = try ctx.projectService.delete(name: projectName, sessionService: ctx.sessionService)
            return .projectDeleted(project: project, sessionCount: deletedCount)
        }

        private func interactive(ctx: AppContext) throws -> String {
            let projects = try ctx.projectService.list()

            if projects.isEmpty {
                throw RockyError.projectNotFound("")
            }

            print()
            print(Table.renderProjects(projects))
            print()

            while true {
                print("Delete which? ", terminator: "")
                guard let line = readLine() else {
                    throw RockyError.sessionInputCancelled
                }
                let input = line.trimmingCharacters(in: .whitespaces)
                if input.isEmpty {
                    print("Enter a project name.")
                    continue
                }
                return input
            }
        }
    }
}
