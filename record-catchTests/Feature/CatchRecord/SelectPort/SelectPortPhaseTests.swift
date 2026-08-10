import XCTest
@testable import record_catch

final class SelectPortPhaseTests: XCTestCase {

    func test_departure_keysAndIdentifierFragment() {
        let phase = SelectPortPhase.departure
        XCTAssertEqual(phase.titleKey, "catchRecord.selectPort.departure.heading")
        XCTAssertEqual(phase.hintKey, "catchRecord.selectPort.departure.hint")
        XCTAssertEqual(phase.validationKey, "catchRecord.selectPort.departure.validation.none")
        XCTAssertEqual(phase.accessibilityIdentifierFragment, "departure")
    }

    func test_return_keysAndIdentifierFragment() {
        let phase = SelectPortPhase.return
        XCTAssertEqual(phase.titleKey, "catchRecord.selectPort.return.heading")
        XCTAssertEqual(phase.hintKey, "catchRecord.selectPort.return.hint")
        XCTAssertEqual(phase.validationKey, "catchRecord.selectPort.return.validation.none")
        XCTAssertEqual(phase.accessibilityIdentifierFragment, "return")
    }
}
