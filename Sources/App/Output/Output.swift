func output(_ text: String) {
    print()
    print(text)
    print()
}

func output(_ result: CommandResult, options: OutputOptions) {
    switch options.output {
    case .text:
        print()
        print(OutputFormatter.formatText(result))
        print()
    case .json:
        print(OutputFormatter.formatJSON(result))
    }
}
