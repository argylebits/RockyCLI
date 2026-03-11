import Testing
import Foundation
@testable import RockyCore

@Suite("Session Model")
struct SessionModelTests {
    @Test("duration calculates from start to end")
    func duration() {
        let start = Date()
        let end = start.addingTimeInterval(3600)
        let session = Session(id: 1, projectId: 1, startTime: start, endTime: end)
        #expect(session.duration() == 3600)
        #expect(!session.isRunning)
    }

    @Test("running session uses current time for duration")
    func runningDuration() {
        let start = Date().addingTimeInterval(-120)
        let session = Session(id: 1, projectId: 1, startTime: start, endTime: nil)
        #expect(session.isRunning)
        #expect(session.duration() >= 120)
    }
}
