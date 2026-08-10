import XCTest
@testable import record_catch

final class SelectVesselValidationTests: XCTestCase {

    func test_errorKey_noSelection_returnsValidationKey() {
        XCTAssertEqual(
            SelectVesselValidation.errorKey(for: nil),
            "catchRecord.selectVessel.validation.none"
        )
    }

    func test_errorKey_withSelection_returnsNil() {
        XCTAssertNil(SelectVesselValidation.errorKey(for: "ACHILLES"))
    }
}
