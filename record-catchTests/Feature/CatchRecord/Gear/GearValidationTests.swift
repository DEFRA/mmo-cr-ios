import XCTest
@testable import record_catch

final class GearValidationTests: XCTestCase {

    // MARK: - SelectGearValidation

    func test_selectGear_emptySelection_returnsError() {
        XCTAssertEqual(SelectGearValidation.errorKey(for: []), "catchRecord.selectGear.validation.none")
    }

    func test_selectGear_withSelection_returnsNil() {
        XCTAssertNil(SelectGearValidation.errorKey(for: ["seine"]))
    }

    // MARK: - AddGearValidation

    func test_addGear_messageWhenQueryBlank_asksUserToEnter() {
        XCTAssertEqual(
            AddGearValidation.message(query: "", selectedGear: nil),
            ValidationMessage("catchRecord.addGear.validation.enter")
        )
    }

    func test_addGear_messageWhenWhitespaceOnly_treatedAsBlank() {
        XCTAssertEqual(
            AddGearValidation.message(query: "   ", selectedGear: nil),
            ValidationMessage("catchRecord.addGear.validation.enter")
        )
    }

    func test_addGear_messageWhenTypedButNothingSelected_asksUserToSelectFromList() {
        XCTAssertEqual(
            AddGearValidation.message(query: "Sein", selectedGear: nil),
            ValidationMessage("catchRecord.addGear.validation.none")
        )
    }

    func test_addGear_messageWithValidSelection_isNil() {
        XCTAssertNil(AddGearValidation.message(query: GearOption.seineNets.name, selectedGear: .seineNets))
    }

    // MARK: - GearMeasurementValidation

    func test_parse_validWholeNumber() {
        XCTAssertEqual(GearMeasurementValidation.parse(" 100 "), 100)
        XCTAssertEqual(GearMeasurementValidation.parse("1"), 1)
    }

    func test_parse_invalidValues_returnNil() {
        XCTAssertNil(GearMeasurementValidation.parse(""))
        XCTAssertNil(GearMeasurementValidation.parse("abc"))
        XCTAssertNil(GearMeasurementValidation.parse("-5"))
        XCTAssertNil(GearMeasurementValidation.parse("10.5"))
    }

    /// A measurement of zero is never physically possible (e.g. a mesh size or times-shot count of
    /// 0mm/0 times), so it must be rejected even though it is a valid whole number.
    func test_parse_zero_returnsNil() {
        XCTAssertNil(GearMeasurementValidation.parse("0"))
        XCTAssertNil(GearMeasurementValidation.parse(" 0 "))
    }

    func test_errorKey_reflectsValidity() {
        XCTAssertNil(GearMeasurementValidation.errorKey(for: "100"))
        XCTAssertEqual(
            GearMeasurementValidation.errorKey(for: "x"),
            "catchRecord.gear.measurement.validation.wholeNumber"
        )
    }

    func test_errorKey_forZero_returnsGreaterThanZeroKey() {
        XCTAssertEqual(
            GearMeasurementValidation.errorKey(for: "0"),
            "catchRecord.gear.measurement.validation.greaterThanZero"
        )
    }
}
