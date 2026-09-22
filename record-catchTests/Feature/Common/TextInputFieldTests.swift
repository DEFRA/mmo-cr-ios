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

    func testPasswordToggleLabelWhenHiddenPromptsToShow() {
        XCTAssertEqual(TextInputField.passwordToggleLabel(isVisible: false), "Show password")
    }

    func testPasswordToggleLabelWhenVisiblePromptsToHide() {
        XCTAssertEqual(TextInputField.passwordToggleLabel(isVisible: true), "Hide password")
    }

    // MARK: - sanitizedDecimalInput

    func testSanitizedDecimalInputPassesThroughAValidWholeNumber() {
        XCTAssertEqual(TextInputField.sanitizedDecimalInput("12"), "12")
    }

    func testSanitizedDecimalInputPassesThroughAValidDecimal() {
        XCTAssertEqual(TextInputField.sanitizedDecimalInput("12.5"), "12.5")
    }

    func testSanitizedDecimalInputKeepsOnlyTheFirstDecimalPointWhenDotsAreRepeatedFromEmpty() {
        // Reported bug: tapping the decimal-pad's "." key repeatedly then entering digits.
        XCTAssertEqual(TextInputField.sanitizedDecimalInput("......888"), ".888")
    }

    func testSanitizedDecimalInputKeepsOnlyTheFirstDecimalPointBetweenDigitGroups() {
        // Reported bug: digits, then repeated dots, then more digits.
        XCTAssertEqual(TextInputField.sanitizedDecimalInput("11......2222"), "11.2222")
    }

    func testSanitizedDecimalInputDropsAnySecondDecimalPoint() {
        XCTAssertEqual(TextInputField.sanitizedDecimalInput("1.2.3"), "1.23")
    }

    func testSanitizedDecimalInputDropsNonNumericCharacters() {
        XCTAssertEqual(TextInputField.sanitizedDecimalInput("1a2b.5c"), "12.5")
    }

    func testSanitizedDecimalInputReturnsEmptyStringForEmptyInput() {
        XCTAssertEqual(TextInputField.sanitizedDecimalInput(""), "")
    }

    func testSanitizedDecimalInputIsIdempotent() {
        let once = TextInputField.sanitizedDecimalInput("......888")
        let twice = TextInputField.sanitizedDecimalInput(once)
        XCTAssertEqual(once, twice)
    }
}
