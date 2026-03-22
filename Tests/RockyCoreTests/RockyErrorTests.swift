import Foundation
import Testing
@testable import RockyCore

@Suite("RockyError")
struct RockyErrorTests {

    // MARK: - Existing cases (from RockyCoreError)

    @Test("invalidRow description")
    func invalidRow() {
        let error = RockyError.invalidRow("projects")
        #expect(error.description == "Invalid row data in projects table")
    }

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

    @Test("sessionNotFound description")
    func sessionNotFound() {
        let error = RockyError.sessionNotFound(42)
        #expect(error.description == "No session found with ID 42.")
    }

    @Test("cannotEditRunningSessionStop description")
    func cannotEditRunningSessionStop() {
        let error = RockyError.cannotEditRunningSessionStop
        #expect(error.description == "Cannot edit the stop time of a running session. Stop it first.")
    }

    @Test("startTimeInFuture description")
    func startTimeInFuture() {
        let error = RockyError.startTimeInFuture
        #expect(error.description == "Start time cannot be in the future.")
    }

    @Test("stopBeforeStart description")
    func stopBeforeStart() {
        let error = RockyError.stopBeforeStart
        #expect(error.description == "Stop time must be after start time.")
    }

    @Test("durationNotPositive description")
    func durationNotPositive() {
        let error = RockyError.durationNotPositive
        #expect(error.description == "Duration must be positive.")
    }

    @Test("overdetermined description")
    func overdetermined() {
        let error = RockyError.overdetermined
        #expect(error.description == "Cannot specify --start, --stop, and --duration together.")
    }

    // MARK: - New cases (absorbed from ValidationError)

    @Test("timerAlreadyRunning description")
    func timerAlreadyRunning() {
        let error = RockyError.timerAlreadyRunning("Acme Corp")
        #expect(error.description == "Timer already running for Acme Corp")
    }

    @Test("noTimerRunning with project name description")
    func noTimerRunningWithProject() {
        let error = RockyError.noTimerRunning("Acme Corp")
        #expect(error.description == "No timer running for Acme Corp.")
    }

    @Test("noTimerRunning without project name description")
    func noTimerRunningNoProject() {
        let error = RockyError.noTimerRunning(nil)
        #expect(error.description == "No timers currently running.")
    }

    @Test("invalidDateFormat description")
    func invalidDateFormat() {
        let error = RockyError.invalidDateFormat("not-a-date")
        #expect(error.description == "Invalid date format: not-a-date. Use YYYY-MM-DD.")
    }

    @Test("inputCancelled description")
    func inputCancelled() {
        let error = RockyError.inputCancelled
        #expect(error.description == "Input cancelled.")
    }

    @Test("missingArgument description")
    func missingArgument() {
        let error = RockyError.missingArgument("Provide a project name for interactive mode or --session for non-interactive mode.")
        #expect(error.description == "Provide a project name for interactive mode or --session for non-interactive mode.")
    }

    @Test("configKeyNotSet description")
    func configKeyNotSet() {
        let error = RockyError.configKeyNotSet("auto-stop")
        #expect(error.description == "Key \"auto-stop\" is not set.")
    }

    // MARK: - Equatable

    @Test("errors with same case and value are equal")
    func equatable() {
        #expect(RockyError.projectNotFound("x") == RockyError.projectNotFound("x"))
        #expect(RockyError.timerAlreadyRunning("y") == RockyError.timerAlreadyRunning("y"))
        #expect(RockyError.sessionNotFound(1) == RockyError.sessionNotFound(1))
        #expect(RockyError.inputCancelled == RockyError.inputCancelled)
    }

    @Test("errors with different cases are not equal")
    func notEquatable() {
        #expect(RockyError.projectNotFound("x") != RockyError.projectAlreadyExists("x"))
        #expect(RockyError.sessionNotFound(1) != RockyError.sessionNotFound(2))
    }
}
