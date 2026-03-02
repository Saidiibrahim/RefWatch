import XCTest
@testable import RefWatchCore

final class MisconductTemplateCatalogTests: XCTestCase {
    func testTemplateForNilReturnsDefault() {
        let template = MisconductTemplateCatalog.template(for: nil)
        XCTAssertEqual(template.id, MisconductTemplateCatalog.defaultTemplateID)
    }

    func testTemplateForUnknownReturnsDefault() {
        let template = MisconductTemplateCatalog.template(for: "unknown_template")
        XCTAssertEqual(template.id, MisconductTemplateCatalog.defaultTemplateID)
    }

    func testFootballSouthAustraliaPlayerReasonsMatchExpectedCounts() {
        let template = MisconductTemplateCatalog.template(for: MisconductTemplateCatalog.defaultTemplateID)
        let yellowReasons = template.reasons(for: .yellow, recipient: .player)
        let redReasons = template.reasons(for: .red, recipient: .player)

        XCTAssertEqual(yellowReasons.count, 7)
        XCTAssertEqual(redReasons.count, 7)

        XCTAssertTrue(yellowReasons.contains(where: { $0.code == "Y1" }))
        XCTAssertTrue(yellowReasons.contains(where: { $0.code == "Y7" }))
        XCTAssertTrue(redReasons.contains(where: { $0.code == "R7" }))

        let r7 = redReasons.first(where: { $0.code == "R7" })
        XCTAssertEqual(r7?.minimumSuspensionMatches, 1)
        XCTAssertEqual(r7?.regulationReference, "Table 2")
    }

    func testFootballSouthAustraliaTeamOfficialReasonsMatchExpectedCounts() {
        let template = MisconductTemplateCatalog.template(for: MisconductTemplateCatalog.defaultTemplateID)
        let yellowReasons = template.reasons(for: .yellow, recipient: .teamOfficial)
        let redReasons = template.reasons(for: .red, recipient: .teamOfficial)

        XCTAssertEqual(yellowReasons.count, 4)
        XCTAssertEqual(redReasons.count, 4)
        XCTAssertTrue(redReasons.contains(where: { $0.code == "RT3" }))
    }
}
