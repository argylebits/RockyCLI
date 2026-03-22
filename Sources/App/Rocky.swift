import ArgumentParser

@main
struct Rocky: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "rocky",
        abstract: "A CLI time tracking tool.",
        version: rockyVersion,
        subcommands: [Sessions.self, Start.self, Stop.self, Status.self, Dashboard.self, Config.self, Projects.self]
    )
}
