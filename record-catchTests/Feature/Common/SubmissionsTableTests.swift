import SwiftUI
import XCTest
@testable import record_catch

final class SubmissionsTableTests: XCTestCase {

    // MARK: - Header rendering

    func testHeaderTitles_includesCreatedByColumnInOrder() {
        let titles = SubmissionsTable.headerTitles(
            endDate: "Trip end date",
            vessel: "Vessel",
            status: "Status",
            createdBy: "Created by"
        )
        XCTAssertEqual(titles, ["Trip end date", "Vessel", "Status", "Created by"])
    }

    func testHeaderTitles_hasFourColumns() {
        let titles = SubmissionsTable.headerTitles(
            endDate: "A", vessel: "B", status: "C", createdBy: "D"
        )
        XCTAssertEqual(titles.count, 4)
    }

    // MARK: - Row model requires Created by

    func testSubmissionRow_carriesCreatedBy() {
        let row = SubmissionRow(
            dateText: "20 Nov 2020",
            vesselName: "ACHILLES",
            status: .submitted,
            createdBy: "J.Smith"
        )
        XCTAssertEqual(row.createdBy, "J.Smith")
        XCTAssertEqual(row.vesselName, "ACHILLES")
        XCTAssertEqual(row.status, .submitted)
    }

    // MARK: - Status colour + text (colour never the sole signal)

    func testEveryStatus_hasDistinctText() {
        let values = SubmissionStatus.allCases.map { $0.rawValue }
        XCTAssertEqual(Set(values).count, SubmissionStatus.allCases.count)
    }
}
