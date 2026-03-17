import RockyCore

struct AppContext {
    let projectService: ProjectService
    let sessionService: SessionService
    let reportService: ReportService
    let dashboardService: DashboardService
    private init(projectService: ProjectService, sessionService: SessionService, reportService: ReportService, dashboardService: DashboardService) {
        self.projectService = projectService
        self.sessionService = sessionService
        self.reportService = reportService
        self.dashboardService = dashboardService
    }

    static func build() async throws -> AppContext {
        let db = try Database.open()
        let projectRepo = SQLiteProjectRepository(db: db)
        let sessionRepo = SQLiteSessionRepository(db: db)
        return AppContext(
            projectService: ProjectService(repository: projectRepo),
            sessionService: SessionService(repository: sessionRepo),
            reportService: ReportService(sessionRepository: sessionRepo, projectRepository: projectRepo),
            dashboardService: DashboardService(sessionRepository: sessionRepo, projectRepository: projectRepo)
        )
    }
}
