import Foundation
import RockyCore

struct AppContext {
    let projectService: ProjectService
    let sessionService: SessionService
    let reportService: ReportService
    let dashboardService: DashboardService
    let config: RockyConfig

    init(projectService: ProjectService, sessionService: SessionService, reportService: ReportService, dashboardService: DashboardService, config: RockyConfig = .default) {
        self.projectService = projectService
        self.sessionService = sessionService
        self.reportService = reportService
        self.dashboardService = dashboardService
        self.config = config
    }

    static func build() throws -> AppContext {
        let db = try Database.open()
        let projectRepo = SQLiteProjectRepository(db: db)
        let sessionRepo = SQLiteSessionRepository(db: db)
        let config = try loadConfig()
        return AppContext(
            projectService: ProjectService(repository: projectRepo),
            sessionService: SessionService(repository: sessionRepo),
            reportService: ReportService(sessionRepository: sessionRepo, projectRepository: projectRepo),
            dashboardService: DashboardService(sessionRepository: sessionRepo, projectRepository: projectRepo),
            config: config
        )
    }

    private static func loadConfig() throws -> RockyConfig {
        let path = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".rocky/config.json")
        guard FileManager.default.fileExists(atPath: path.path) else {
            return .default
        }
        let data = try Data(contentsOf: path)
        return try JSONDecoder().decode(RockyConfig.self, from: data)
    }
}
