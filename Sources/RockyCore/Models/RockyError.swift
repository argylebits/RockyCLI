import Foundation

public enum RockyError: Error, Equatable, CustomStringConvertible {
    // Row mapping
    case invalidRow(String)

    // Projects
    case projectNotFound(String)
    case projectAlreadyExists(String)

    // Sessions
    case sessionNotFound(Int)
    case cannotEditRunningSessionStop
    case startTimeInFuture
    case stopBeforeStart
    case durationNotPositive
    case overdetermined

    // Runtime (absorbed from ValidationError)
    case timerAlreadyRunning(String)
    case noTimerRunning(String?)
    case invalidDateFormat(String)
    case inputCancelled
    case missingArgument(String)
    case configKeyNotSet(String)

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
        case .cannotEditRunningSessionStop:
            return "Cannot edit the stop time of a running session. Stop it first."
        case .startTimeInFuture:
            return "Start time cannot be in the future."
        case .stopBeforeStart:
            return "Stop time must be after start time."
        case .durationNotPositive:
            return "Duration must be positive."
        case .overdetermined:
            return "Cannot specify --start, --stop, and --duration together."
        case .timerAlreadyRunning(let name):
            return "Timer already running for \(name)"
        case .noTimerRunning(let name):
            if let name {
                return "No timer running for \(name)."
            }
            return "No timers currently running."
        case .invalidDateFormat(let input):
            return "Invalid date format: \(input). Use YYYY-MM-DD."
        case .inputCancelled:
            return "Input cancelled."
        case .missingArgument(let detail):
            return detail
        case .configKeyNotSet(let key):
            return "Key \"\(key)\" is not set."
        }
    }
}
