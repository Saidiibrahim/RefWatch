import XCTest
@testable import RefWatchCore

final class MisconductTemplatesCatalogTests: XCTestCase {
    func testAliasMappingReturnsVictoria() {
        // Given a legacy id that previously pointed to Victoria content
        let legacyId = "football_nsw"

        // When we request the template using the legacy id
        let template = MisconductTemplateCatalog.template(for: legacyId)

        // Then we should resolve to Victoria
        XCTAssertEqual(template.id, "football_vic")
        XCTAssertEqual(template.region, "Victoria")
        XCTAssertFalse(template.allReasons.isEmpty)
    }

    func testFAEnglandTemplateHasC1AndS1() {
        let fa = MisconductTemplateCatalog.template(for: "fa_england")
        let codes = Set(fa.allReasons.map { $0.code })
        XCTAssertTrue(codes.contains("C1"))
        XCTAssertTrue(codes.contains("S1"))
    }

    func testUSSFTemplateHasUBAndSFP() {
        let us = MisconductTemplateCatalog.template(for: "ussf")
        let codes = Set(us.allReasons.map { $0.code })
        XCTAssertTrue(codes.contains("UB"))
        XCTAssertTrue(codes.contains("SFP"))
    }

    func testAUStatesPresent() {
        let nnsw = MisconductTemplateCatalog.template(for: "football_nnswf")
        let qld = MisconductTemplateCatalog.template(for: "football_qld")
        XCTAssertEqual(nnsw.region, "Northern NSW")
        XCTAssertEqual(qld.region, "Queensland")
        XCTAssertFalse(nnsw.reasons(for: .yellow, recipient: .player).isEmpty)
        XCTAssertFalse(qld.reasons(for: .red, recipient: .player).isEmpty)
    }
}


