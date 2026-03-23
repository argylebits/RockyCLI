import Foundation
import Testing
@testable import RockyCore

@Suite("RockyError")
struct RockyErrorTests {

    // MARK: - Row mapping

    @Test("invalidRow description")
    func invalidRow() {
        let error = RockyError.invalidRow("projects")
        #expect(error.description == "Invalid row data in projects table")
    }

    // MARK: - Project

    @Test("projectNotFound description")
    func projectNotFound() {
        let error = RockyError.projectNotFound("acme-corp")
        #expect(error.description == "Project not found: acme-corp")
    }

    @Test("projectAlreadyExists description")
    func projectAlreadyExists() {
        let error = RockyError.projectAlreadyExists("acme-corp")
        #expect(error.description == "Project already exists: acme-corp")
    }

    // MARK: - Session

    @Test("sessionNotFound description")
    func sessionNotFound() {
        let error = RockyError.sessionNotFound(42)
        #expect(error.description == "No session found with ID 42.")
    }

    @Test("sessionTimerAlreadyRunning description")
    func sessionTimerAlreadyRunning() {
        let error = RockyError.sessionTimerAlreadyRunning("Acme Corp")
        #expect(error.description == "Timer already running for Acme Corp")
    }

    @Test("sessionNoTimerRunning with project name description")
    func sessionNoTimerRunningWithProject() {
        let error = RockyError.sessionNoTimerRunning("Acme Corp")
        #expect(error.description == "No timer running for Acme Corp.")
    }

    @Test("sessionNoTimerRunning without project name description")
    func sessionNoTimerRunningNoProject() {
        let error = RockyError.sessionNoTimerRunning(nil)
        #expect(error.description == "No timers currently running.")
    }

    @Test("sessionRunningSessionStop description")
    func sessionRunningSessionStop() {
        let error = RockyError.sessionRunningSessionStop
        #expect(error.description == "Cannot edit the stop time of a running session. Stop it first.")
    }

    @Test("sessionStartTimeInFuture description")
    func sessionStartTimeInFuture() {
        let error = RockyError.sessionStartTimeInFuture
        #expect(error.description == "Start time cannot be in the future.")
    }

    @Test("sessionStopBeforeStart description")
    func sessionStopBeforeStart() {
        let error = RockyError.sessionStopBeforeStart
        #expect(error.description == "Stop time must be after start time.")
    }

    @Test("sessionDurationNotPositive description")
    func sessionDurationNotPositive() {
        let error = RockyError.sessionDurationNotPositive
        #expect(error.description == "Duration must be positive.")
    }

    @Test("sessionOverdetermined description")
    func sessionOverdetermined() {
        let error = RockyError.sessionOverdetermined
        #expect(error.description == "Cannot specify --start, --stop, and --duration together.")
    }

    @Test("sessionInvalidDateFormat description")
    func sessionInvalidDateFormat() {
        let error = RockyError.sessionInvalidDateFormat("not-a-date")
        #expect(error.description == "Invalid date format: not-a-date. Use YYYY-MM-DD.")
    }

    @Test("sessionInputCancelled description")
    func sessionInputCancelled() {
        let error = RockyError.sessionInputCancelled
        #expect(error.description == "Input cancelled.")
    }

    @Test("sessionMissingArgument description")
    func sessionMissingArgument() {
        let error = RockyError.sessionMissingArgument("Provide a project name for interactive mode or --session for non-interactive mode.")
        #expect(error.description == "Provide a project name for interactive mode or --session for non-interactive mode.")
    }

    // MARK: - Config

    @Test("configKeyNotSet description")
    func configKeyNotSet() {
        let error = RockyError.configKeyNotSet("auto-stop")
        #expect(error.description == "Key \"auto-stop\" is not set.")
    }

    // MARK: - Equatable

    @Test("errors with same case and value are equal")
    func equatable() {
        #expect(RockyError.projectNotFound("x") == RockyError.projectNotFound("x"))
        #expect(RockyError.sessionTimerAlreadyRunning("y") == RockyError.sessionTimerAlreadyRunning("y"))
        #expect(RockyError.sessionNotFound(1) == RockyError.sessionNotFound(1))
        #expect(RockyError.sessionInputCancelled == RockyError.sessionInputCancelled)
    }

    @Test("errors with different cases are not equal")
    func notEquatable() {
        #expect(RockyError.projectNotFound("x") != RockyError.projectAlreadyExists("x"))
        #expect(RockyError.sessionNotFound(1) != RockyError.sessionNotFound(2))
    }

    // MARK: - Code

    @Test("invalidRow code")
    func invalidRowCode() {
        #expect(RockyError.invalidRow("projects").code == "invalid_row")
    }

    @Test("projectNotFound code")
    func projectNotFoundCode() {
        #expect(RockyError.projectNotFound("x").code == "project_not_found")
    }

    @Test("projectAlreadyExists code")
    func projectAlreadyExistsCode() {
        #expect(RockyError.projectAlreadyExists("x").code == "project_already_exists")
    }

    @Test("sessionNotFound code")
    func sessionNotFoundCode() {
        #expect(RockyError.sessionNotFound(1).code == "session_not_found")
    }

    @Test("sessionTimerAlreadyRunning code")
    func sessionTimerAlreadyRunningCode() {
        #expect(RockyError.sessionTimerAlreadyRunning("x").code == "session_timer_already_running")
    }

    @Test("sessionNoTimerRunning code")
    func sessionNoTimerRunningCode() {
        #expect(RockyError.sessionNoTimerRunning("x").code == "session_no_timer_running")
    }

    @Test("sessionRunningSessionStop code")
    func sessionRunningSessionStopCode() {
        #expect(RockyError.sessionRunningSessionStop.code == "session_running_session_stop")
    }

    @Test("sessionStartTimeInFuture code")
    func sessionStartTimeInFutureCode() {
        #expect(RockyError.sessionStartTimeInFuture.code == "session_start_time_in_future")
    }

    @Test("sessionStopBeforeStart code")
    func sessionStopBeforeStartCode() {
        #expect(RockyError.sessionStopBeforeStart.code == "session_stop_before_start")
    }

    @Test("sessionDurationNotPositive code")
    func sessionDurationNotPositiveCode() {
        #expect(RockyError.sessionDurationNotPositive.code == "session_duration_not_positive")
    }

    @Test("sessionOverdetermined code")
    func sessionOverdeterminedCode() {
        #expect(RockyError.sessionOverdetermined.code == "session_overdetermined")
    }

    @Test("sessionInvalidDateFormat code")
    func sessionInvalidDateFormatCode() {
        #expect(RockyError.sessionInvalidDateFormat("x").code == "session_invalid_date_format")
    }

    @Test("sessionInputCancelled code")
    func sessionInputCancelledCode() {
        #expect(RockyError.sessionInputCancelled.code == "session_input_cancelled")
    }

    @Test("sessionMissingArgument code")
    func sessionMissingArgumentCode() {
        #expect(RockyError.sessionMissingArgument("x").code == "session_missing_argument")
    }

    @Test("configKeyNotSet code")
    func configKeyNotSetCode() {
        #expect(RockyError.configKeyNotSet("x").code == "config_key_not_set")
    }

    // MARK: - Encodable

    @Test("encodes to JSON with code and message keys")
    func encodable() throws {
        let error = RockyError.projectNotFound("acme-corp")
        let data = try JSONEncoder().encode(error)
        let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(obj["code"] as? String == "project_not_found")
        #expect(obj["message"] as? String == "Project not found: acme-corp")
    }

    @Test("encodes plain case to JSON")
    func encodablePlainCase() throws {
        let error = RockyError.sessionOverdetermined
        let data = try JSONEncoder().encode(error)
        let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(obj["code"] as? String == "session_overdetermined")
        #expect(obj["message"] as? String == "Cannot specify --start, --stop, and --duration together.")
    }
}
