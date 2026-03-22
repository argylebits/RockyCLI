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
}
