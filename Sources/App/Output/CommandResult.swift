import Foundation
import RockyCore

enum CommandResult {
    // Session
    case sessionStarted(session: Session, project: Project, otherRunning: [String])
    case sessionStopped(sessions: [Session], projects: [Project])
    case sessionStatus(statuses: [ProjectStatus])
    case sessionTodayTotals(totals: ProjectTotals, period: String, sessions: [Session], projects: [Project])
    case sessionGrouped(report: GroupedReport, period: String, projectFilter: String?, hoursOnly: Bool, sessions: [Session], projects: [Project])
    case sessionVerbose(sessions: [VerboseSessionRow], period: String, projectFilter: String?)
    case sessionEdited(session: Session)

    // Project
    case projectList(projects: [Project])
    case projectRenamed(oldName: String, project: Project)

    // Dashboard
    case dashboard(data: DashboardData)

    // Config
    case configValue(key: String, value: String)
    case configList(entries: [(key: String, value: String)])

    // Generic
    case message(String)
}
