import Foundation
import Testing
@testable import App

@Suite("RockyConfig")
struct RockyConfigTests {

    @Test("decodes auto-stop true from string value")
    func decodesAutoStopTrue() throws {
        let json = Data(#"{"auto-stop":"true"}"#.utf8)
        let config = try JSONDecoder().decode(RockyConfig.self, from: json)
        #expect(config.autoStop == true)
    }

    @Test("decodes auto-stop false from string value")
    func decodesAutoStopFalse() throws {
        let json = Data(#"{"auto-stop":"false"}"#.utf8)
        let config = try JSONDecoder().decode(RockyConfig.self, from: json)
        #expect(config.autoStop == false)
    }

    @Test("defaults auto-stop to true when key is missing")
    func defaultsWhenMissing() throws {
        let json = Data(#"{}"#.utf8)
        let config = try JSONDecoder().decode(RockyConfig.self, from: json)
        #expect(config.autoStop == true)
    }

    @Test("default config has auto-stop true")
    func defaultConfig() {
        #expect(RockyConfig.default.autoStop == true)
    }
}
