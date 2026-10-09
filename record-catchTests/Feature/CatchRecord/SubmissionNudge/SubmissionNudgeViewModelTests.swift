import XCTest
@testable import record_catch

@MainActor
final class SubmissionNudgeViewModelTests: XCTestCase {

    private let vessel = "ACHILLES"
    private let referenceNumber = "A1234520260727150815"

    func test_initialState_exposesInputs() {
        let sut = SubmissionNudgeViewModel(
            daysLate: 3,
            vessel: vessel,
            referenceNumber: referenceNumber,
            router: CatchRecordRouter()
        )
        XCTAssertEqual(sut.daysLate, 3)
        XCTAssertEqual(sut.vessel, vessel)
        XCTAssertEqual(sut.referenceNumber, referenceNumber)
    }

    // MARK: - checkTripEndDate

    func test_checkTripEndDate_opensReturnDateScreenInChangeMode() {
        let router = CatchRecordRouter()
        let draft = CatchRecordDraft()
        router.push(.submissionNudge(daysLate: 3, vessel: vessel, referenceNumber: referenceNumber))
        let sut = SubmissionNudgeViewModel(daysLate: 3, vessel: vessel, referenceNumber: referenceNumber, router: router, draft: draft)

        sut.checkTripEndDate()

        XCTAssertEqual(
            router.path,
            [
                .submissionNudge(daysLate: 3, vessel: vessel, referenceNumber: referenceNumber),
                .tripDate(phase: .return, vessel: vessel, referenceNumber: referenceNumber, departureDate: nil)
            ]
        )
        XCTAssertTrue(draft.returnToCheckYourAnswers)
    }

    func test_checkTripEndDate_threadsCapturedDepartureDate() {
        let router = CatchRecordRouter()
        let draft = CatchRecordDraft()
        let departureDate = Date(timeIntervalSince1970: 1_000_000)
        draft.departureDate = departureDate
        let sut = SubmissionNudgeViewModel(daysLate: 3, vessel: vessel, referenceNumber: referenceNumber, router: router, draft: draft)

        sut.checkTripEndDate()

        XCTAssertEqual(
            router.path,
            [.tripDate(phase: .return, vessel: vessel, referenceNumber: referenceNumber, departureDate: departureDate)]
        )
    }

    // MARK: - submit → Check your catch record

    func test_submit_pushesCheckYourAnswers() {
        let router = CatchRecordRouter()
        let sut = SubmissionNudgeViewModel(daysLate: 3, vessel: vessel, referenceNumber: referenceNumber, router: router)

        sut.submit()

        XCTAssertEqual(router.path, [.checkYourAnswers(referenceNumber: referenceNumber)])
    }
}
