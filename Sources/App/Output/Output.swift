import Foundation
import RockyCore

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

func outputError(_ error: RockyError, options: OutputOptions) {
    switch options.output {
    case .text:
        FileHandle.standardError.write(Data("\nError: \(error.description)\n\n".utf8))
    case .json:
        print(OutputFormatter.formatError(error))
    }
}
