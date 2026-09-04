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
}
