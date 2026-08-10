import XCTest
@testable import record_catch

@MainActor
final class TripStartedTodayViewModelTests: XCTestCase {

    private let referenceNumber = "A1234520260727150815"

    func test_initialState_hasNoSelectionAndNoError_exposesReferenceNumber() {
        let sut = TripStartedTodayViewModel(referenceNumber: referenceNumber, router: CatchRecordRouter())
        XCTAssertNil(sut.selection)
        XCTAssertNil(sut.errorKey)
        XCTAssertEqual(sut.referenceNumber, referenceNumber)
    }

    func test_submit_withNoSelection_setsError_andDoesNotRoute() {
        let router = CatchRecordRouter()
        let sut = TripStartedTodayViewModel(referenceNumber: referenceNumber, router: router)

        sut.submit()

        XCTAssertEqual(sut.errorKey, "catchRecord.tripToday.validation.none")
        XCTAssertTrue(router.path.isEmpty)
    }

    func test_submit_withYesSelection_pushesPlaceholderNextStep() {
        let router = CatchRecordRouter()
        let sut = TripStartedTodayViewModel(referenceNumber: referenceNumber, router: router)
        sut.selection = .yes

        sut.submit()

        XCTAssertNil(sut.errorKey)
        XCTAssertEqual(router.path, [.placeholderNextStep])
    }

    func test_submit_withNoSelection_pushesTripDateDepartureWithNoDepartureDate() {
        let router = CatchRecordRouter()
        let sut = TripStartedTodayViewModel(referenceNumber: referenceNumber, router: router)
        sut.selection = .no

        sut.submit()

        XCTAssertNil(sut.errorKey)
        XCTAssertEqual(
            router.path,
            [.tripDate(phase: .departure, referenceNumber: referenceNumber, departureDate: nil)]
        )
    }

    func test_errorKey_beforeSubmit_isNil() {
        let sut = TripStartedTodayViewModel(referenceNumber: referenceNumber, router: CatchRecordRouter())
        XCTAssertNil(sut.errorKey)
    }
}
