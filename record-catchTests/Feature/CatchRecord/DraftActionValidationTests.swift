import XCTest
@testable import record_catch

final class DraftActionValidationTests: XCTestCase {

    func test_errorKey_noSelection_returnsValidationKey() {
        XCTAssertEqual(
            DraftActionValidation.errorKey(for: nil),
            "catchRecord.draftAction.validation.none"
        )
    }

    func test_errorKey_completeSelected_returnsNil() {
        XCTAssertNil(DraftActionValidation.errorKey(for: .complete))
    }

    func test_errorKey_deleteSelected_returnsNil() {
        XCTAssertNil(DraftActionValidation.errorKey(for: .delete))
    }
}
