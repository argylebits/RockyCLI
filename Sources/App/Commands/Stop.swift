import ArgumentParser

struct Stop: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Stop a running timer.",
        shouldDisplay: false
    )

    @Argument(help: "The project name to stop tracking.")
    var project: String?

    @Flag(name: .long, help: "Stop all running timers.")
    var all: Bool = false

    func run() throws {
        var cmd = Sessions.Stop()
        cmd.project = project
        cmd.all = all
        try cmd.run()
    }
}
