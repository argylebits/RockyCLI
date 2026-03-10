import Foundation
import Testing
@testable import App
@testable import RockyCore

@Suite("Table Alignment")
struct TableAlignmentTests {
    @Test("active and inactive rows have same column alignment")
    func indicatorWidthConsistency() {
        let statuses = [
            ProjectStatus(
                project: Project(id: 1, parentId: nil, name: "acme-corp", createdAt: Date()),
                runningSession: Session(id: 1, projectId: 1, startTime: Date().addingTimeInterval(-3600), endTime: nil)
            ),
            ProjectStatus(
                project: Project(id: 2, parentId: nil, name: "side-project", createdAt: Date()),
                runningSession: nil
            ),
        ]

        let output = Table.renderStatus(statuses)
        let lines = output.split(separator: "\n", omittingEmptySubsequences: false)

        // Find the column position of "Project" in the header
        let headerLine = String(lines[0])
        let headerProjectIndex = headerLine.range(of: "Project")!.lowerBound

        // Find the column position of "acme-corp" in the active row (after divider)
        let activeLine = String(lines[2])
        let activeNameIndex = activeLine.range(of: "acme-corp")!.lowerBound

        // Find the column position of "side-project" in the inactive row
        let inactiveLine = String(lines[3])
        let inactiveNameIndex = inactiveLine.range(of: "side-project")!.lowerBound

        // All first-column content should start at the same position
        let headerOffset = headerLine.distance(from: headerLine.startIndex, to: headerProjectIndex)
        let activeOffset = activeLine.distance(from: activeLine.startIndex, to: activeNameIndex)
        let inactiveOffset = inactiveLine.distance(from: inactiveLine.startIndex, to: inactiveNameIndex)

        #expect(headerOffset == activeOffset, "Header and active row should align")
        #expect(headerOffset == inactiveOffset, "Header and inactive row should align")
    }

    @Test("footer total row aligns with data rows")
    func footerAlignment() {
        let totals = ProjectTotals(
            entries: [
                ProjectTotalEntry(projectName: "acme-corp", duration: 7200, isRunning: true),
                ProjectTotalEntry(projectName: "side-project", duration: 3600, isRunning: false),
            ]
        )

        let output = Table.renderTodayTotals(totals, period: "Friday 06 Mar 2026")
        let lines = output.split(separator: "\n", omittingEmptySubsequences: false)

        // Find data line and footer line by content
        var dataLine: String?
        var footerLine: String?
        for line in lines {
            let s = String(line)
            if s.contains("acme-corp") { dataLine = s }
            if s.contains("Total") && !s.contains("Project") { footerLine = s }
        }

        guard let data = dataLine, let footer = footerLine else {
            #expect(Bool(false), "Could not find data and footer lines")
            return
        }

        // The first cell content should start at the same column
        let dataStart = data.firstIndex(where: { $0 != " " && $0 != "\u{25B6}" })!
        let footerStart = footer.firstIndex(where: { $0 != " " })!

        let dataOffset = data.distance(from: data.startIndex, to: dataStart)
        let footerOffset = footer.distance(from: footer.startIndex, to: footerStart)

        #expect(dataOffset == footerOffset, "Footer 'Total' should align with data row project names")
    }
}
