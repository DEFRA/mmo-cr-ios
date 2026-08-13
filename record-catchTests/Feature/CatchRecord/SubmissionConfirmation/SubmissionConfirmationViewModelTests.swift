import XCTest
@testable import record_catch

/// Always-succeeding stub submission service for exercising the happy path deterministically,
/// with no real delay.
private struct StubSuccessSubmissionService: CatchRecordSubmissionServicing {
    func submit(referenceNumber: String) async throws {}
}

private struct StubFailingSubmissionService: CatchRecordSubmissionServicing {
    func submit(referenceNumber: String) async throws {
        throw CatchRecordSubmissionError.network
    }
}

/// Mutable mock so a single view model instance can be retried after a failure — the first
/// `submit()` fails, the second succeeds — to test the "clears submitFailed on retry" behaviour
/// without recreating the view model (as a real retry-after-reconnect would look).
private final class MockRetrySubmissionService: CatchRecordSubmissionServicing, @unchecked Sendable {
    var shouldFail = true

    func submit(referenceNumber: String) async throws {
        if shouldFail { throw CatchRecordSubmissionError.network }
    }
}

@MainActor
final class SubmissionConfirmationViewModelTests: XCTestCase {

    private let referenceNumber = "A1234520260727150815"

    // MARK: - Error visibility

    func test_errorKey_beforeSubmitAttempted_isNilEvenWhenUnconfirmed() {
        let sut = SubmissionConfirmationViewModel(referenceNumber: referenceNumber, router: CatchRecordRouter())

        XCTAssertNil(sut.errorKey)
    }

    func test_errorKey_afterFailedSubmit_isShown() async {
        let sut = SubmissionConfirmationViewModel(referenceNumber: referenceNumber, router: CatchRecordRouter())

        await sut.submit()

        XCTAssertEqual(sut.errorKey, "catchRecord.submissionConfirmation.validation.none")
    }

    func test_errorKey_afterFailedSubmit_thenConfirming_clearsError() async {
        let sut = SubmissionConfirmationViewModel(referenceNumber: referenceNumber, router: CatchRecordRouter())
        await sut.submit()

        sut.isConfirmed = true

        XCTAssertNil(sut.errorKey)
    }

    // MARK: - Submit routing

    func test_submit_whenNotConfirmed_doesNotRoute() async {
        let router = CatchRecordRouter()
        let sut = SubmissionConfirmationViewModel(referenceNumber: referenceNumber, router: router)

        await sut.submit()

        XCTAssertTrue(router.path.isEmpty)
    }

    func test_submit_whenConfirmed_pushesSubmissionSuccessOntoRouter() async {
        let router = CatchRecordRouter()
        let sut = SubmissionConfirmationViewModel(
            referenceNumber: referenceNumber,
            router: router,
            submissionService: StubSuccessSubmissionService()
        )
        sut.isConfirmed = true

        await sut.submit()

        XCTAssertEqual(router.path, [.submissionSuccess(referenceNumber: referenceNumber)])
    }

    // MARK: - Submission failure (error-handling path — 100% coverage requirement)

    func test_submit_whenSubmissionServiceFails_setsSubmitFailed_andDoesNotRoute() async {
        let router = CatchRecordRouter()
        let sut = SubmissionConfirmationViewModel(
            referenceNumber: referenceNumber,
            router: router,
            submissionService: StubFailingSubmissionService()
        )
        sut.isConfirmed = true

        await sut.submit()

        XCTAssertTrue(sut.submitFailed)
        XCTAssertTrue(router.path.isEmpty)
    }

    func test_submit_retryAfterFailure_clearsSubmitFailed_andRoutesOnSuccess() async {
        let router = CatchRecordRouter()
        let service = MockRetrySubmissionService()
        let sut = SubmissionConfirmationViewModel(referenceNumber: referenceNumber, router: router, submissionService: service)
        sut.isConfirmed = true

        await sut.submit()
        XCTAssertTrue(sut.submitFailed)
        XCTAssertTrue(router.path.isEmpty)

        // User is back online; retapping "Accept and submit trip details" now succeeds.
        service.shouldFail = false
        await sut.submit()

        XCTAssertFalse(sut.submitFailed)
        XCTAssertEqual(router.path, [.submissionSuccess(referenceNumber: referenceNumber)])
    }

    func test_isSubmitting_isFalseAfterSubmitCompletes() async {
        let sut = SubmissionConfirmationViewModel(
            referenceNumber: referenceNumber,
            router: CatchRecordRouter(),
            submissionService: StubSuccessSubmissionService()
        )
        sut.isConfirmed = true

        await sut.submit()

        XCTAssertFalse(sut.isSubmitting)
    }
}
