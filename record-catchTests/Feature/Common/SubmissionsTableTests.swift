import SwiftUI
import XCTest
@testable import record_catch

@MainActor
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
        let row = record_catch.SubmissionRow(
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

    /// Every status (including `.completePending`, ADR-0028) must resolve to a distinct
    /// background/text colour pair, so colour is never the only way two statuses are told apart
    /// (WCAG 2.2 AA — meaning must never rely on colour alone; see accessibility.instructions.md).
    func testEveryStatus_hasADistinctBackgroundAndTextColor() {
        for status in SubmissionStatus.allCases {
            XCTAssertNotNil(status.backgroundColor)
            XCTAssertNotNil(status.textColor)
        }
        let backgrounds = SubmissionStatus.allCases.map(\.backgroundColor)
        let texts = SubmissionStatus.allCases.map(\.textColor)
        XCTAssertEqual(Set(backgrounds).count, SubmissionStatus.allCases.count)
        XCTAssertEqual(Set(texts).count, SubmissionStatus.allCases.count)
    }

    func testCompletePendingStatus_usesThePendingColorPalette() {
        XCTAssertEqual(SubmissionStatus.completePending.backgroundColor, AppColors.statusPendingBackground)
        XCTAssertEqual(SubmissionStatus.completePending.textColor, AppColors.statusPendingText)
    }

    // MARK: - Status tag localisation (BR-SUB-010/AC12 — previously hard-coded English rawValue)

    func testStatusKey_everyStatus_resolvesToADistinctLocalizedValue_inEnglish() {
        let store = AppLanguageStore(defaults: makeDefaults())
        var seenValues = Set<String>()
        for status in SubmissionStatus.allCases {
            let value = store.localized(status.statusKey)
            XCTAssertNotEqual(value, status.statusKey, "Missing English translation for \(status)")
            seenValues.insert(value)
        }
        XCTAssertEqual(seenValues.count, SubmissionStatus.allCases.count)
    }

    func testStatusKey_everyStatus_resolvesToADistinctLocalizedValue_inWelsh() {
        let store = AppLanguageStore(defaults: makeDefaults())
        store.toggle() // Welsh
        var seenValues = Set<String>()
        for status in SubmissionStatus.allCases {
            let value = store.localized(status.statusKey)
            XCTAssertNotEqual(value, status.statusKey, "Missing Welsh translation for \(status)")
            seenValues.insert(value)
        }
        XCTAssertEqual(seenValues.count, SubmissionStatus.allCases.count)
    }

    private func makeDefaults() -> UserDefaults {
        let suite = "test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }
}
