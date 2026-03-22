import Foundation
import RockyCore

struct StopEntry {
    let name: String
    let duration: TimeInterval
}

enum CommandResult {
    // Session
    case sessionStarted(project: String, running: [String])
    case sessionStopped(entries: [StopEntry])
    case sessionStatus(statuses: [ProjectStatus])
    case sessionTodayTotals(totals: ProjectTotals, period: String)
    case sessionGrouped(report: GroupedReport, period: String, projectFilter: String?, hoursOnly: Bool)
    case sessionVerbose(sessions: [VerboseSessionRow], period: String, projectFilter: String?)
    case sessionEdited(session: Session)

    // Project
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
