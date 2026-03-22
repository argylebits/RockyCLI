import Foundation
import RockyCore

struct StopEntry {
    let name: String
    let duration: TimeInterval
}

enum CommandResult {
    // Sessions
    case started(project: String, running: [String])
    case stopped(entries: [StopEntry])
    case status(statuses: [ProjectStatus])
    case todayTotals(totals: ProjectTotals, period: String)
    case grouped(report: GroupedReport, period: String, projectFilter: String?, hoursOnly: Bool)
    case verbose(sessions: [VerboseSessionRow], period: String, projectFilter: String?)
    case edited(session: Session)

    // Projects
    case projectList(projects: [Project])
    case projectRenamed(oldName: String, newName: String)

    // Dashboard
    case dashboard(data: DashboardData)

    // Config
    case configValue(key: String, value: String)
    case configList(entries: [(key: String, value: String)])

    // Generic
    case message(String)
}
