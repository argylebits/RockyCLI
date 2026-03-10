import ArgumentParser

@main
struct Rocky: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "rocky",
        abstract: "A CLI time tracking tool.",
        version: rockyVersion,
        subcommands: [Start.self, Stop.self, Status.self, Config.self, Projects.self]
    )
}
