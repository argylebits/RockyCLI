import ArgumentParser
import Foundation
import RockyCore

struct Dashboard: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Show an analytics dashboard with trends and insights."
    )

    func run() async throws {
        let ctx = try await AppContext.build()

        let data = try await ctx.dashboardService.generate()
        output(DashboardRenderer.render(data))
    }
}
