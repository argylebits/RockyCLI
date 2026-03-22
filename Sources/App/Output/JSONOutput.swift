import Foundation
import RockyCore

// MARK: - Envelope

struct JSONEnvelope<T: Encodable>: Encodable {
    let command: String
    let data: T
}

// MARK: - Session

struct SessionStartJSON: Encodable {
    let project: String
    let running: [String]
}

struct SessionStopEntryJSON: Encodable {
    let project: String
    let duration: Int
}

struct SessionStopJSON: Encodable {
    let sessions: [SessionStopEntryJSON]
}

struct SessionStatusEntryJSON: Encodable {
    let project: String
    let slug: String
    let running: Bool
    let duration: Int?
    let startTime: String?
}

struct SessionStatusJSON: Encodable {
    let projects: [SessionStatusEntryJSON]
}

struct SessionTotalEntryJSON: Encodable {
    let project: String
    let duration: Int
    let running: Bool
}

struct SessionTodayJSON: Encodable {
    let period: String
    let total: Int
    let entries: [SessionTotalEntryJSON]
}

struct SessionGroupedRowJSON: Encodable {
    let project: String
    let running: Bool
    let total: Int
    let durations: [String: Int]
}

struct SessionGroupedJSON: Encodable {
    let period: String
    let columns: [String]
    let rows: [SessionGroupedRowJSON]
    let grandTotal: Int
    let projectFilter: String?
}

struct SessionVerboseEntryJSON: Encodable {
    let id: Int
    let project: String
    let startTime: String
    let endTime: String?
    let duration: Int
    let running: Bool
}

struct SessionVerboseJSON: Encodable {
    let period: String
    let sessions: [SessionVerboseEntryJSON]
    let total: Int
    let projectFilter: String?
}

struct SessionEditedJSON: Encodable {
    let id: Int
    let startTime: String
    let endTime: String?
    let duration: Int
    let running: Bool
}

// MARK: - Project

struct ProjectJSON: Encodable {
    let id: Int
    let name: String
    let slug: String
    let createdAt: String
}

struct ProjectListJSON: Encodable {
    let projects: [ProjectJSON]
}

struct ProjectRenameJSON: Encodable {
    let oldName: String
    let newName: String
}

// MARK: - Dashboard

struct DashboardTimeSummaryJSON: Encodable {
    let thisWeek: Int
    let lastWeek: Int
    let thisMonth: Int
    let lastMonth: Int
    let thisYear: Int
}

struct DashboardRunningTimerJSON: Encodable {
    let project: String
    let duration: Int
}

struct DashboardStatsJSON: Encodable {
    let currentStreak: Int
    let longestStreak: Int
    let sessionsThisWeek: Int
    let averageSessionDuration: Int
    let dailyAvgWeek: Int
    let totalHours: Int
}

struct DashboardJSON: Encodable {
    let runningTimers: [DashboardRunningTimerJSON]
    let timeSummary: DashboardTimeSummaryJSON
    let stats: DashboardStatsJSON
}

// MARK: - Config

struct ConfigValueJSON: Encodable {
    let key: String
    let value: String
}

struct ConfigListJSON: Encodable {
    let entries: [ConfigValueJSON]
}

// MARK: - Message

struct MessageJSON: Encodable {
    let message: String
}
