import XCTest
@testable import record_catch

/// Exercises `TripDateViewModel.dateWasAdjustedForAgeLimit` — the resumed-stale-draft notice for
/// the departure-date screen (see BR-CAT-006/AC02, `CatchRecordDateRules.earliestSelectableTripDate`).
///
/// Split out of `TripDateViewModelTests` purely to keep that file's class body within the
/// project's `type_body_length` SwiftLint limit; the behaviour under test is part of the same
/// view model.
@MainActor
final class TripDateAgeLimitAdjustmentTests: XCTestCase {

    private let vessel = "ACHILLES"
    private let referenceNumber = "A1234520260727150815"
    private let calendar = Calendar(identifier: .gregorian)

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar(identifier: .gregorian).date(from: DateComponents(year: year, month: month, day: day))!
    }

    /// A resumed draft's departure date that is now more than 365 days in the past (the rolling
    /// limit has moved past it since it was captured) must be surfaced to the user, not silently
    /// re-dated with no feedback.
    func test_init_departure_whenResumedDateIsMoreThan365DaysInThePast_flagsAdjustment() {
        let today = date(2026, 4, 3)
        let draft = CatchRecordDraft()
        draft.departureDate = calendar.date(byAdding: .day, value: -400, to: today)

        let sut = TripDateViewModel(
            phase: .departure,
            vessel: vessel,
            referenceNumber: referenceNumber,
            departureDate: nil,
            router: CatchRecordRouter(),
            draft: draft,
            now: { today }
        )

        XCTAssertTrue(sut.dateWasAdjustedForAgeLimit)
        XCTAssertEqual(sut.selectedDate, sut.selectableRange.lowerBound)
    }

    func test_init_departure_whenResumedDateIsWithin365Days_doesNotFlagAdjustment() {
        let today = date(2026, 4, 3)
        let draft = CatchRecordDraft()
        draft.departureDate = calendar.date(byAdding: .day, value: -10, to: today)

        let sut = TripDateViewModel(
            phase: .departure,
            vessel: vessel,
            referenceNumber: referenceNumber,
            departureDate: nil,
            router: CatchRecordRouter(),
            draft: draft,
            now: { today }
        )

        XCTAssertFalse(sut.dateWasAdjustedForAgeLimit)
    }

    /// Only the departure phase has a rolling age-limit floor — the return phase's lower bound is
    /// the departure date, so no age-limit adjustment notice applies there.
    func test_init_return_neverFlagsAgeLimitAdjustment() {
        let today = date(2026, 4, 3)
        let draft = CatchRecordDraft()
        draft.returnDate = calendar.date(byAdding: .day, value: -400, to: today)

        let sut = TripDateViewModel(
            phase: .return,
            vessel: vessel,
            referenceNumber: referenceNumber,
            departureDate: calendar.date(byAdding: .day, value: -500, to: today),
            router: CatchRecordRouter(),
            draft: draft,
            now: { today }
        )

        XCTAssertFalse(sut.dateWasAdjustedForAgeLimit)
    }

    func test_init_withNoExistingDraftDate_doesNotFlagAdjustment() {
        let today = date(2026, 4, 3)
        let sut = TripDateViewModel(
            phase: .departure,
            vessel: vessel,
            referenceNumber: referenceNumber,
            departureDate: nil,
            router: CatchRecordRouter(),
            draft: CatchRecordDraft(),
            now: { today }
        )

        XCTAssertFalse(sut.dateWasAdjustedForAgeLimit)
    }
}
