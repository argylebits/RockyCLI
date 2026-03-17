import ArgumentParser
import Foundation
import RockyCore

struct Dashboard: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Show an analytics dashboard with trends and insights."
    )

    func run() throws {
        let ctx = try AppContext.build()

        let data = try ctx.dashboardService.generate()
        output(DashboardRenderer.render(data))
    }
}
