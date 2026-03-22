import ArgumentParser

struct Start: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Start a timer for a project.",
        shouldDisplay: false
    )

    @Argument(help: "The project name to start tracking.")
    var project: String

    @OptionGroup var outputOptions: OutputOptions

    func run() throws {
        var cmd = Sessions.Start()
        cmd.project = project
        cmd.outputOptions = outputOptions
        try cmd.run()
    }
}
