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

    func test_addGear_noSelection_returnsError() {
        XCTAssertEqual(AddGearValidation.errorKey(for: nil), "catchRecord.addGear.validation.none")
    }

    func test_addGear_withSelection_returnsNil() {
        XCTAssertNil(AddGearValidation.errorKey(for: .seineNets))
    }

    // MARK: - GearMeasurementValidation

    func test_parse_validWholeNumber() {
        XCTAssertEqual(GearMeasurementValidation.parse(" 100 "), 100)
        XCTAssertEqual(GearMeasurementValidation.parse("0"), 0)
    }

    func test_parse_invalidValues_returnNil() {
        XCTAssertNil(GearMeasurementValidation.parse(""))
        XCTAssertNil(GearMeasurementValidation.parse("abc"))
        XCTAssertNil(GearMeasurementValidation.parse("-5"))
        XCTAssertNil(GearMeasurementValidation.parse("10.5"))
    }

    func test_errorKey_reflectsValidity() {
        XCTAssertNil(GearMeasurementValidation.errorKey(for: "100"))
        XCTAssertEqual(
            GearMeasurementValidation.errorKey(for: "x"),
            "catchRecord.gear.measurement.validation.wholeNumber"
        )
    }
}
