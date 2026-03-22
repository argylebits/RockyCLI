import ArgumentParser

enum OutputFormat: String, ExpressibleByArgument {
    case text
    case json
}

struct OutputOptions: ParsableArguments {
    @Option(name: .long, help: "Output format (text or json).")
    var output: OutputFormat = .text
}
