import Foundation
import Testing
@testable import App

@Suite("Sessions Command Group")
struct SessionsCommandTests {

    // MARK: - rocky sessions start

    @Test("rocky sessions start parses project argument")
    func sessionsStartParsesProject() throws {
        let cmd = try Rocky.parseAsRoot(["sessions", "start", "acme-corp"])
        #expect(cmd is Sessions.Start)
        let start = cmd as! Sessions.Start
        #expect(start.project == "acme-corp")
    }

    // MARK: - rocky sessions stop

    @Test("rocky sessions stop parses with no arguments")
    func sessionsStopNoArgs() throws {
        let cmd = try Rocky.parseAsRoot(["sessions", "stop"])
        #expect(cmd is Sessions.Stop)
        let stop = cmd as! Sessions.Stop
        #expect(stop.project == nil)
        #expect(stop.all == false)
    }

    @Test("rocky sessions stop parses project argument")
    func sessionsStopParsesProject() throws {
        let cmd = try Rocky.parseAsRoot(["sessions", "stop", "acme-corp"])
        #expect(cmd is Sessions.Stop)
        let stop = cmd as! Sessions.Stop
        #expect(stop.project == "acme-corp")
    }

    @Test("rocky sessions stop parses --all flag")
    func sessionsStopAll() throws {
        let cmd = try Rocky.parseAsRoot(["sessions", "stop", "--all"])
        #expect(cmd is Sessions.Stop)
        let stop = cmd as! Sessions.Stop
        #expect(stop.all == true)
    }

    // MARK: - rocky sessions status

    @Test("rocky sessions status parses with no flags")
    func sessionsStatusNoFlags() throws {
        let cmd = try Rocky.parseAsRoot(["sessions", "status"])
        #expect(cmd is Sessions.Status)
    }

    @Test("rocky sessions status parses --today flag")
    func sessionsStatusToday() throws {
        let cmd = try Rocky.parseAsRoot(["sessions", "status", "--today"])
        #expect(cmd is Sessions.Status)
        let status = cmd as! Sessions.Status
        #expect(status.today == true)
    }

    @Test("rocky sessions status parses --week flag")
    func sessionsStatusWeek() throws {
        let cmd = try Rocky.parseAsRoot(["sessions", "status", "--week"])
        #expect(cmd is Sessions.Status)
        let status = cmd as! Sessions.Status
        #expect(status.week == true)
    }

    @Test("rocky sessions status parses --verbose flag")
    func sessionsStatusVerbose() throws {
        let cmd = try Rocky.parseAsRoot(["sessions", "status", "--verbose"])
        #expect(cmd is Sessions.Status)
        let status = cmd as! Sessions.Status
        #expect(status.verbose == true)
    }

    @Test("rocky sessions status parses --project option")
    func sessionsStatusProject() throws {
        let cmd = try Rocky.parseAsRoot(["sessions", "status", "--today", "--project", "acme-corp"])
        #expect(cmd is Sessions.Status)
        let status = cmd as! Sessions.Status
        #expect(status.project == "acme-corp")
    }

    // MARK: - rocky sessions edit

    @Test("rocky sessions edit parses project argument")
    func sessionsEditProject() throws {
        let cmd = try Rocky.parseAsRoot(["sessions", "edit", "acme-corp"])
        #expect(cmd is Sessions.Edit)
        let edit = cmd as! Sessions.Edit
        #expect(edit.project == "acme-corp")
    }

    @Test("rocky sessions edit parses --session option")
    func sessionsEditSession() throws {
        let cmd = try Rocky.parseAsRoot(["sessions", "edit", "--session", "42"])
        #expect(cmd is Sessions.Edit)
        let edit = cmd as! Sessions.Edit
        #expect(edit.session == 42)
    }

    @Test("rocky sessions edit parses all non-interactive flags")
    func sessionsEditAllFlags() throws {
        let cmd = try Rocky.parseAsRoot(["sessions", "edit", "--session", "42", "--start", "2026-03-10 09:00", "--stop", "2026-03-10 17:00"])
        #expect(cmd is Sessions.Edit)
        let edit = cmd as! Sessions.Edit
        #expect(edit.session == 42)
        #expect(edit.start == "2026-03-10 09:00")
        #expect(edit.stop == "2026-03-10 17:00")
    }

    // MARK: - rocky sessions (no subcommand)

    @Test("rocky sessions with no subcommand parses as group")
    func sessionsNoSubcommand() throws {
        let cmd = try Rocky.parseAsRoot(["sessions"])
        #expect(cmd is Sessions)
    }

    // MARK: - Top-level shortcuts

    @Test("rocky start shortcut parses project argument")
    func startShortcut() throws {
        let cmd = try Rocky.parseAsRoot(["start", "acme-corp"])
        #expect(cmd is Start)
        let start = cmd as! Start
        #expect(start.project == "acme-corp")
    }

    @Test("rocky stop shortcut parses with no arguments")
    func stopShortcut() throws {
        let cmd = try Rocky.parseAsRoot(["stop"])
        #expect(cmd is Stop)
    }

    @Test("rocky status shortcut parses with no flags")
    func statusShortcut() throws {
        let cmd = try Rocky.parseAsRoot(["status"])
        #expect(cmd is Status)
    }

    // MARK: - rocky edit removed as top-level

    @Test("rocky edit is not a recognized top-level command")
    func editNotTopLevel() {
        #expect(throws: (any Error).self) {
            _ = try Rocky.parseAsRoot(["edit", "acme-corp"])
        }
    }
}
