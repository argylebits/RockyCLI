import ArgumentParser

@main
struct Rocky: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "rocky",
        abstract: "A CLI time tracking tool.",
        version: rockyVersion,
        subcommands: [Start.self, Stop.self, Status.self, Edit.self, Dashboard.self, Config.self, Projects.self]
    )
}
