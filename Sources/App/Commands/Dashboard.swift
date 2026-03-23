import ArgumentParser
import Foundation
import RockyCore

struct Dashboard: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Show an analytics dashboard with trends and insights."
    )

    @OptionGroup var outputOptions: OutputOptions

    func run() throws {
        do {
            let ctx = try AppContext.build()
            let result = try execute(ctx: ctx)
            output(result, options: outputOptions)
        } catch let error as RockyError {
            outputError(error, options: outputOptions)
            throw ExitCode.failure
        }
    }

    @discardableResult
    func execute(ctx: AppContext) throws -> CommandResult {
        let data = try ctx.dashboardService.generate()
        return .dashboard(data: data)
    }
}
