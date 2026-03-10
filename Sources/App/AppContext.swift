import RockyCore

struct AppContext {
    let projectService: ProjectService
    let sessionService: SessionService
    let reportService: ReportService
    private let db: Database

    private init(db: Database, projectService: ProjectService, sessionService: SessionService, reportService: ReportService) {
        self.db = db
        self.projectService = projectService
        self.sessionService = sessionService
        self.reportService = reportService
    }

    static func build() async throws -> AppContext {
        let db = try await Database.open()
        let projectRepo = SQLiteProjectRepository(db: db)
        let sessionRepo = SQLiteSessionRepository(db: db)
        return AppContext(
            db: db,
            projectService: ProjectService(repository: projectRepo),
            sessionService: SessionService(repository: sessionRepo),
            reportService: ReportService(sessionRepository: sessionRepo, projectRepository: projectRepo)
        )
    }

    func close() async throws {
        try await db.close()
    }
}
