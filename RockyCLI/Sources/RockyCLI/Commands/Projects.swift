import ArgumentParser
import RockyCore

struct Projects: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "List all projects."
    )

    func run() async throws {
        let db = try await Database.open()
        defer { Task { try? await db.close() } }

        let projectService = ProjectService(db: db)
        let projects = try await projectService.list()

        if projects.isEmpty {
            print("No projects found.")
            return
        }

        print(Table.renderProjects(projects))
    }
}
