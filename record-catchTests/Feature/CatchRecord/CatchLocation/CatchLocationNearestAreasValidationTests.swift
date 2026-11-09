import XCTest
@testable import record_catch

final class CatchLocationNearestAreasValidationTests: XCTestCase {

    func test_errorKey_whenNil_returnsValidationKey() {
        XCTAssertEqual(
            CatchLocationNearestAreasValidation.errorKey(for: nil),
            "catchRecord.nearestAreas.validation.none"
        )
    }

    func test_errorKey_whenEmpty_returnsValidationKey() {
        XCTAssertEqual(
            CatchLocationNearestAreasValidation.errorKey(for: ""),
            "catchRecord.nearestAreas.validation.none"
        )
    }

    func test_errorKey_whenAreaSelected_isNil() {
        XCTAssertNil(CatchLocationNearestAreasValidation.errorKey(for: "38E96"))
    }

    func test_errorKey_whenOtherSelected_isNil() {
        // "Other" is itself a valid RadioGroup selection on this screen (see
        // CatchLocationNearestAreasViewModel.otherOptionID) — only *no* selection is invalid.
        XCTAssertNil(CatchLocationNearestAreasValidation.errorKey(for: "other"))
    }
}
