import Foundation

public enum RockyError: Error, Equatable, CustomStringConvertible {
    // Row mapping
    case invalidRow(String)

    // Project
    case projectNotFound(String)
    case projectAlreadyExists(String)

    // Session
    case sessionNotFound(Int)
    case sessionTimerAlreadyRunning(String)
    case sessionNoTimerRunning(String?)
    case sessionRunningSessionStop
    case sessionStartTimeInFuture
    case sessionStopBeforeStart
    case sessionDurationNotPositive
    case sessionOverdetermined
    case sessionInvalidDateFormat(String)
    case sessionInputCancelled
    case sessionMissingArgument(String)

    // Config
    case configKeyNotSet(String)

    public var code: String {
        switch self {
        case .invalidRow: return "invalid_row"
        case .projectNotFound: return "project_not_found"
        case .projectAlreadyExists: return "project_already_exists"
        case .sessionNotFound: return "session_not_found"
        case .sessionTimerAlreadyRunning: return "session_timer_already_running"
        case .sessionNoTimerRunning: return "session_no_timer_running"
        case .sessionRunningSessionStop: return "session_running_session_stop"
        case .sessionStartTimeInFuture: return "session_start_time_in_future"
        case .sessionStopBeforeStart: return "session_stop_before_start"
        case .sessionDurationNotPositive: return "session_duration_not_positive"
        case .sessionOverdetermined: return "session_overdetermined"
        case .sessionInvalidDateFormat: return "session_invalid_date_format"
        case .sessionInputCancelled: return "session_input_cancelled"
        case .sessionMissingArgument: return "session_missing_argument"
        case .configKeyNotSet: return "config_key_not_set"
        }
    }

    public var description: String {
        switch self {
        case .invalidRow(let table):
            return "Invalid row data in \(table) table"
        case .projectNotFound(let name):
            return "Project not found: \(name)"
        case .projectAlreadyExists(let name):
            return "Project already exists: \(name)"
        case .sessionNotFound(let id):
            return "No session found with ID \(id)."
        case .sessionTimerAlreadyRunning(let name):
            return "Timer already running for \(name)"
        case .sessionNoTimerRunning(let name):
            if let name {
                return "No timer running for \(name)."
            }
            return "No timers currently running."
        case .sessionRunningSessionStop:
            return "Cannot edit the stop time of a running session. Stop it first."
        case .sessionStartTimeInFuture:
            return "Start time cannot be in the future."
        case .sessionStopBeforeStart:
            return "Stop time must be after start time."
        case .sessionDurationNotPositive:
            return "Duration must be positive."
        case .sessionOverdetermined:
            return "Cannot specify --start, --stop, and --duration together."
        case .sessionInvalidDateFormat(let input):
            return "Invalid date format: \(input). Use YYYY-MM-DD."
        case .sessionInputCancelled:
            return "Input cancelled."
        case .sessionMissingArgument(let detail):
            return detail
        case .configKeyNotSet(let key):
            return "Key \"\(key)\" is not set."
        }
    }
}

extension RockyError: Encodable {
    private enum CodingKeys: String, CodingKey {
        case code, message
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(code, forKey: .code)
        try container.encode(description, forKey: .message)
    }
}
