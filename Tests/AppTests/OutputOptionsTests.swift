import Testing
@testable import App

@Suite("OutputOptions")
struct OutputOptionsTests {

    @Test("OutputFormat parses text")
    func parseText() {
        let format = OutputFormat(rawValue: "text")
        #expect(format == .text)
    }

    @Test("OutputFormat parses json")
    func parseJson() {
        let format = OutputFormat(rawValue: "json")
        #expect(format == .json)
    }

    @Test("OutputFormat rejects invalid value")
    func parseInvalid() {
        let format = OutputFormat(rawValue: "xml")
        #expect(format == nil)
    }

    @Test("OutputFormat default raw value is text")
    func defaultFormat() {
        #expect(OutputFormat.text.rawValue == "text")
    }
}
