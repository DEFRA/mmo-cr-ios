import XCTest
@testable import record_catch

final class CatchRecordRoutingTests: XCTestCase {

    func test_entryRoute_forUnsentRow_returnsDraftActionRoute() {
        let row = record_catch.SubmissionRow(dateText: "20 Nov 2020", vesselName: "ACHILLES", status: .unsent, createdBy: "J.Smith")

        XCTAssertEqual(CatchRecordRouting.entryRoute(for: row), .draftAction(row))
    }

    func test_entryRoute_forSubmittedRow_returnsNil() {
        let row = record_catch.SubmissionRow(dateText: "20 Nov 2020", vesselName: "ACHILLES", status: .submitted, createdBy: "J.Smith")

        XCTAssertNil(CatchRecordRouting.entryRoute(for: row))
    }

    func test_entryRoute_forAmendedRow_returnsNil() {
        let row = record_catch.SubmissionRow(dateText: "20 Nov 2020", vesselName: "ACHILLES", status: .amended, createdBy: "J.Smith")

        XCTAssertNil(CatchRecordRouting.entryRoute(for: row))
    }

    func test_entryRoute_forLateRow_returnsNil() {
        let row = record_catch.SubmissionRow(dateText: "20 Nov 2020", vesselName: "ACHILLES", status: .late, createdBy: "J.Smith")

        XCTAssertNil(CatchRecordRouting.entryRoute(for: row))
    }
}
