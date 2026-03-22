import ArgumentParser

struct Status: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Show time tracking summary.",
        shouldDisplay: false
    )

    @Flag(name: .long, help: "Show totals for today.")
    var today: Bool = false

    @Flag(name: .long, help: "Show totals by day for the current week.")
    var week: Bool = false

    @Flag(name: .long, help: "Show totals by week for the current month.")
    var month: Bool = false

    @Flag(name: .long, help: "Show totals by month for the current year.")
    var year: Bool = false

    @Option(name: .long, help: "Custom range start (YYYY-MM-DD).")
    var from: String?

    @Option(name: .long, help: "Custom range end (YYYY-MM-DD). Defaults to today.")
    var to: String?

    @Flag(name: .shortAndLong, help: "Show individual sessions with start/stop times.")
    var verbose: Bool = false

    @Option(name: .long, help: "Filter to a single project.")
    var project: String?

    @OptionGroup var outputOptions: OutputOptions

    func run() throws {
        var cmd = Sessions.Status()
        cmd.today = today
        cmd.week = week
        cmd.month = month
        cmd.year = year
        cmd.from = from
        cmd.to = to
        cmd.verbose = verbose
        cmd.project = project
        cmd.outputOptions = outputOptions
        try cmd.run()
    }
}
