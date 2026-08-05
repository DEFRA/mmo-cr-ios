import XCTest
@testable import record_catch

final class TextInputFieldTests: XCTestCase {

    func testIsBlankReturnsTrueForWhitespaceOnlyInput() {
        XCTAssertTrue(TextInputField.isBlank("   \n\t"))
    }

    func testIsBlankReturnsFalseForNonWhitespaceInput() {
        XCTAssertFalse(TextInputField.isBlank("password123"))
    }

    func testShouldShowRequiredErrorReturnsFalseWhenFieldIsNotRequired() {
        let shouldShowError = TextInputField.shouldShowRequiredError(
            text: "",
            didAttemptSubmit: true,
            hasBlurred: true,
            isRequired: false
        )

        XCTAssertFalse(shouldShowError)
    }

    func testShouldShowRequiredErrorReturnsFalseBeforeBlurOrSubmit() {
        let shouldShowError = TextInputField.shouldShowRequiredError(
            text: "",
            didAttemptSubmit: false,
            hasBlurred: false,
            isRequired: true
        )

        XCTAssertFalse(shouldShowError)
    }

    func testShouldShowRequiredErrorReturnsTrueAfterSubmitWhenInputIsBlank() {
        let shouldShowError = TextInputField.shouldShowRequiredError(
            text: "  ",
            didAttemptSubmit: true,
            hasBlurred: false,
            isRequired: true
        )

        XCTAssertTrue(shouldShowError)
    }

    func testShouldShowRequiredErrorReturnsFalseAfterSubmitWhenInputHasValue() {
        let shouldShowError = TextInputField.shouldShowRequiredError(
            text: "james.wilson@company.co.uk",
            didAttemptSubmit: true,
            hasBlurred: false,
            isRequired: true
        )

        XCTAssertFalse(shouldShowError)
    }
}
