import XCTest
@testable import record_catch

final class SubmissionConfirmationValidationTests: XCTestCase {

    func test_errorKey_whenConfirmed_isNil() {
        XCTAssertNil(SubmissionConfirmationValidation.errorKey(for: true))
    }

    func test_errorKey_whenNotConfirmed_returnsValidationKey() {
        XCTAssertEqual(
            SubmissionConfirmationValidation.errorKey(for: false),
            "catchRecord.submissionConfirmation.validation.none"
        )
    }
}
