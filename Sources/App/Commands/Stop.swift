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

    @OptionGroup var outputOptions: OutputOptions

    func run() throws {
        var cmd = Sessions.Stop()
        cmd.project = project
        cmd.all = all
        cmd.outputOptions = outputOptions
        try cmd.run()
    }
}
