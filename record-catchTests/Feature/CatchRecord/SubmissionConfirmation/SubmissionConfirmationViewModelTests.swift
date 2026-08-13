import XCTest
@testable import record_catch

@MainActor
final class SubmissionConfirmationViewModelTests: XCTestCase {

    private let referenceNumber = "A1234520260727150815"

    // MARK: - Error visibility

    func test_errorKey_beforeSubmitAttempted_isNilEvenWhenUnconfirmed() {
        let sut = SubmissionConfirmationViewModel(referenceNumber: referenceNumber, router: CatchRecordRouter())

        XCTAssertNil(sut.errorKey)
    }

    func test_errorKey_afterFailedSubmit_isShown() {
        let sut = SubmissionConfirmationViewModel(referenceNumber: referenceNumber, router: CatchRecordRouter())

        sut.submit()

        XCTAssertEqual(sut.errorKey, "catchRecord.submissionConfirmation.validation.none")
    }

    func test_errorKey_afterFailedSubmit_thenConfirming_clearsError() {
        let sut = SubmissionConfirmationViewModel(referenceNumber: referenceNumber, router: CatchRecordRouter())
        sut.submit()

        sut.isConfirmed = true

        XCTAssertNil(sut.errorKey)
    }

    // MARK: - Submit routing

    func test_submit_whenNotConfirmed_doesNotRoute() {
        let router = CatchRecordRouter()
        let sut = SubmissionConfirmationViewModel(referenceNumber: referenceNumber, router: router)

        sut.submit()

        XCTAssertTrue(router.path.isEmpty)
    }

    func test_submit_whenConfirmed_pushesPlaceholderNextStepOntoRouter() {
        let router = CatchRecordRouter()
        let sut = SubmissionConfirmationViewModel(referenceNumber: referenceNumber, router: router)
        sut.isConfirmed = true

        sut.submit()

        XCTAssertEqual(router.path, [.placeholderNextStep])
    }
}
