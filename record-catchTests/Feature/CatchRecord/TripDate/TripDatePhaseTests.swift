import XCTest
@testable import record_catch

@MainActor
final class TripDatePhaseTests: XCTestCase {

    func test_departure_copyKeysAndIdentifierFragment() {
        XCTAssertEqual(TripDatePhase.departure.titleKey, "catchRecord.tripDate.departure.title")
        XCTAssertEqual(TripDatePhase.departure.hintKey, "catchRecord.tripDate.departure.hint")
        XCTAssertEqual(TripDatePhase.departure.accessibilityIdentifierFragment, "departure")
    }

    func test_return_copyKeysAndIdentifierFragment() {
        XCTAssertEqual(TripDatePhase.return.titleKey, "catchRecord.tripDate.return.title")
        XCTAssertEqual(TripDatePhase.return.hintKey, "catchRecord.tripDate.return.hint")
        XCTAssertEqual(TripDatePhase.return.accessibilityIdentifierFragment, "return")
    }

    func test_tripDateRoute_equality_dependsOnPhaseReferenceAndDate() {
        let date = Date(timeIntervalSince1970: 1_000)
        let a = CatchRecordRoute.tripDate(phase: .departure, vessel: "ACHILLES", referenceNumber: "REF", departureDate: nil)
        let b = CatchRecordRoute.tripDate(phase: .departure, vessel: "ACHILLES", referenceNumber: "REF", departureDate: nil)
        let differentPhase = CatchRecordRoute.tripDate(phase: .return, vessel: "ACHILLES", referenceNumber: "REF", departureDate: date)

        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, differentPhase)
    }
}
