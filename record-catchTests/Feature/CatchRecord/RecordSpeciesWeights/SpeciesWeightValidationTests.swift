import XCTest
@testable import record_catch

final class SpeciesWeightValidationTests: XCTestCase {

    private let species = "Atlantic cod (COD)"

    // MARK: - parse (oneDecimalPlace)

    func test_parse_oneDecimalPlace_wholeNumber_isValid() {
        XCTAssertEqual(SpeciesWeightValidation.parse("12", precision: .oneDecimalPlace), 12)
    }

    func test_parse_oneDecimalPlace_singleDecimal_isValid() {
        XCTAssertEqual(SpeciesWeightValidation.parse("12.5", precision: .oneDecimalPlace), 12.5)
    }

    func test_parse_oneDecimalPlace_twoDecimals_isNil() {
        XCTAssertNil(SpeciesWeightValidation.parse("12.55", precision: .oneDecimalPlace))
    }

    func test_parse_oneDecimalPlace_empty_isNil() {
        XCTAssertNil(SpeciesWeightValidation.parse("", precision: .oneDecimalPlace))
    }

    func test_parse_oneDecimalPlace_whitespaceOnly_isNil() {
        XCTAssertNil(SpeciesWeightValidation.parse("   ", precision: .oneDecimalPlace))
    }

    func test_parse_oneDecimalPlace_nonNumeric_isNil() {
        XCTAssertNil(SpeciesWeightValidation.parse("abc", precision: .oneDecimalPlace))
    }

    func test_parse_oneDecimalPlace_negative_isNil() {
        // A leading "-" is not a digit or ".", so it is rejected as a format error, not silently
        // parsed into a negative value.
        XCTAssertNil(SpeciesWeightValidation.parse("-1.5", precision: .oneDecimalPlace))
    }

    func test_parse_oneDecimalPlace_commaDecimalSeparator_isNil() {
        XCTAssertNil(SpeciesWeightValidation.parse("1,5", precision: .oneDecimalPlace))
    }

    func test_parse_oneDecimalPlace_trimsWhitespace() {
        XCTAssertEqual(SpeciesWeightValidation.parse(" 1.5 ", precision: .oneDecimalPlace), 1.5)
    }

    // MARK: - parse (wholeNumber)

    func test_parse_wholeNumber_valid() {
        XCTAssertEqual(SpeciesWeightValidation.parse("12", precision: .wholeNumber), 12)
    }

    func test_parse_wholeNumber_withDecimal_isNil() {
        XCTAssertNil(SpeciesWeightValidation.parse("12.0", precision: .wholeNumber))
    }

    // MARK: - requiredErrorMessage

    func test_requiredErrorMessage_blank_returnsEnterMessage() {
        let message = SpeciesWeightValidation.requiredErrorMessage(
            for: "",
            speciesName: species,
            precision: .oneDecimalPlace,
            enterKey: "catchRecord.species.weight.validation.enter"
        )
        XCTAssertEqual(message?.key, "catchRecord.species.weight.validation.enter")
        XCTAssertEqual(message?.arguments, [species])
    }

    func test_requiredErrorMessage_wrongPrecision_returnsDecimalPlaceMessage() {
        let message = SpeciesWeightValidation.requiredErrorMessage(
            for: "12.55",
            speciesName: species,
            precision: .oneDecimalPlace,
            enterKey: "catchRecord.species.weight.validation.enter"
        )
        XCTAssertEqual(message?.key, "catchRecord.species.weight.validation.decimalPlace")
    }

    func test_requiredErrorMessage_wrongPrecision_wholeNumber_returnsWholeNumberMessage() {
        let message = SpeciesWeightValidation.requiredErrorMessage(
            for: "12.5",
            speciesName: species,
            precision: .wholeNumber,
            enterKey: "catchRecord.species.weight.validation.enter"
        )
        XCTAssertEqual(message?.key, "catchRecord.species.weight.validation.wholeNumber")
    }

    func test_requiredErrorMessage_zero_returnsGreaterThanZeroMessage() {
        let message = SpeciesWeightValidation.requiredErrorMessage(
            for: "0",
            speciesName: species,
            precision: .oneDecimalPlace,
            enterKey: "catchRecord.species.weight.validation.enter"
        )
        XCTAssertEqual(message?.key, "catchRecord.species.weight.validation.greaterThanZero")
    }

    func test_requiredErrorMessage_valid_returnsNil() {
        let message = SpeciesWeightValidation.requiredErrorMessage(
            for: "12.5",
            speciesName: species,
            precision: .oneDecimalPlace,
            enterKey: "catchRecord.species.weight.validation.enter"
        )
        XCTAssertNil(message)
    }

    // MARK: - optionalErrorMessage

    func test_optionalErrorMessage_blank_returnsNil() {
        XCTAssertNil(
            SpeciesWeightValidation.optionalErrorMessage(for: "", speciesName: species, precision: .oneDecimalPlace)
        )
    }

    func test_optionalErrorMessage_invalid_returnsMessage() {
        let message = SpeciesWeightValidation.optionalErrorMessage(
            for: "abc", speciesName: species, precision: .oneDecimalPlace
        )
        XCTAssertEqual(message?.key, "catchRecord.species.weight.validation.decimalPlace")
    }

    func test_optionalErrorMessage_valid_returnsNil() {
        XCTAssertNil(
            SpeciesWeightValidation.optionalErrorMessage(for: "5", speciesName: species, precision: .oneDecimalPlace)
        )
    }

    // MARK: - Maximum catch weight limit (Scenario 10)

    func test_requiredErrorMessage_aboveMax_returnsMaxMessage() {
        let message = SpeciesWeightValidation.requiredErrorMessage(
            for: "10001",
            speciesName: species,
            precision: .wholeNumber,
            enterKey: "catchRecord.species.weight.validation.enter"
        )
        XCTAssertEqual(message?.key, "catchRecord.species.weight.validation.max")
        XCTAssertEqual(message?.arguments, [species])
    }

    func test_requiredErrorMessage_atMax_returnsNil() {
        let message = SpeciesWeightValidation.requiredErrorMessage(
            for: "10000",
            speciesName: species,
            precision: .wholeNumber,
            enterKey: "catchRecord.species.weight.validation.enter"
        )
        XCTAssertNil(message)
    }

    func test_requiredErrorMessage_oneDecimalJustOverMax_returnsMaxMessage() {
        let message = SpeciesWeightValidation.requiredErrorMessage(
            for: "10000.1",
            speciesName: species,
            precision: .oneDecimalPlace,
            enterKey: "catchRecord.species.weight.validation.enter"
        )
        XCTAssertEqual(message?.key, "catchRecord.species.weight.validation.max")
    }

    func test_optionalErrorMessage_aboveMax_returnsMaxMessage() {
        let message = SpeciesWeightValidation.optionalErrorMessage(
            for: "10001", speciesName: species, precision: .wholeNumber
        )
        XCTAssertEqual(message?.key, "catchRecord.species.weight.validation.max")
    }

    func test_requiredErrorMessage_blankTakesPriorityOverMax() {
        // Blankness is checked before the maximum — this just documents that a blank value never
        // reaches the max check (it would be nonsensical to compare "" against 10,000).
        let message = SpeciesWeightValidation.requiredErrorMessage(
            for: "",
            speciesName: species,
            precision: .wholeNumber,
            enterKey: "catchRecord.species.weight.validation.enter"
        )
        XCTAssertEqual(message?.key, "catchRecord.species.weight.validation.enter")
    }

    func test_formatErrorTakesPriorityOverMax() {
        // An over-precision value that also happens to exceed the maximum reports the format
        // error, not the maximum error (GOV.UK priority order: format before range).
        let message = SpeciesWeightValidation.requiredErrorMessage(
            for: "10001.55",
            speciesName: species,
            precision: .oneDecimalPlace,
            enterKey: "catchRecord.species.weight.validation.enter"
        )
        XCTAssertEqual(message?.key, "catchRecord.species.weight.validation.decimalPlace")
    }
}
