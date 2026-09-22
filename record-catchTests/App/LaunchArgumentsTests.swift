import XCTest
@testable import record_catch

final class LaunchArgumentsTests: XCTestCase {

    func test_contains_isTrue_whenFlagPresentInRawArguments() {
        let sut = LaunchArguments(raw: ["-uiTestHome"])
        XCTAssertTrue(sut.contains(.home))
    }

    func test_contains_isFalse_whenFlagAbsentFromRawArguments() {
        let sut = LaunchArguments(raw: ["-someOtherFlag"])
        XCTAssertFalse(sut.contains(.home))
    }

    func test_contains_isFalse_forEmptyArguments() {
        let sut = LaunchArguments(raw: [])
        XCTAssertFalse(sut.contains(.catchRecordNew))
    }

    // MARK: - isUITesting

    func test_isUITesting_isTrue_whenAnyUITestFlagPresent() {
        XCTAssertTrue(LaunchArguments(raw: ["-uiTestHome"]).isUITesting)
        XCTAssertTrue(LaunchArguments(raw: ["-uiTestResetLanguage"]).isUITesting)
        XCTAssertTrue(LaunchArguments(raw: ["-someOtherFlag", "-uiTestCatchRecordNew"]).isUITesting)
    }

    func test_isUITesting_isFalse_whenNoUITestFlagPresent() {
        XCTAssertFalse(LaunchArguments(raw: []).isUITesting)
        XCTAssertFalse(LaunchArguments(raw: ["-someOtherFlag"]).isUITesting)
    }
}
