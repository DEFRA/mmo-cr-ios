import XCTest
@testable import record_catch

@MainActor
final class TripStartedTodayViewModelTests: XCTestCase {

    private let vessel = "ACHILLES"
    private let referenceNumber = "A1234520260727150815"

    func test_initialState_hasNoSelectionAndNoError_exposesReferenceNumber() {
        let sut = TripStartedTodayViewModel(vessel: vessel, referenceNumber: referenceNumber, router: CatchRecordRouter())
        XCTAssertNil(sut.selection)
        XCTAssertNil(sut.errorKey)
        XCTAssertEqual(sut.referenceNumber, referenceNumber)
        XCTAssertEqual(sut.vessel, vessel)
    }

    func test_submit_withNoSelection_setsError_andDoesNotRoute() {
        let router = CatchRecordRouter()
        let sut = TripStartedTodayViewModel(vessel: vessel, referenceNumber: referenceNumber, router: router)

        sut.submit()

        XCTAssertEqual(sut.errorKey, "catchRecord.tripToday.validation.none")
        XCTAssertTrue(router.path.isEmpty)
    }

    func test_enterPortSubJourney_withNoFavourites_pushesAddPort() async {
        let router = CatchRecordRouter()
        let sut = TripStartedTodayViewModel(
            vessel: vessel,
            referenceNumber: referenceNumber,
            router: router,
            favouritePorts: StubFavouritePortsProvider()
        )

        await sut.enterPortSubJourney()

        XCTAssertEqual(
            router.path,
            [.addPort(vessel: vessel, referenceNumber: referenceNumber, returnPhase: nil)]
        )
    }

    func test_enterPortSubJourney_withFavourites_pushesSelectDeparture() async {
        let router = CatchRecordRouter()
        let sut = TripStartedTodayViewModel(
            vessel: vessel,
            referenceNumber: referenceNumber,
            router: router,
            favouritePorts: StubFavouritePortsProvider(initialFavourites: [PortOption(name: "Hastings")])
        )

        await sut.enterPortSubJourney()

        XCTAssertEqual(
            router.path,
            [.selectPort(phase: .departure, vessel: vessel, referenceNumber: referenceNumber)]
        )
    }

    func test_submit_withNoSelection_pushesTripDateDepartureWithNoDepartureDate() {
        let router = CatchRecordRouter()
        let sut = TripStartedTodayViewModel(vessel: vessel, referenceNumber: referenceNumber, router: router)
        sut.selection = .no

        sut.submit()

        XCTAssertNil(sut.errorKey)
        XCTAssertEqual(
            router.path,
            [.tripDate(phase: .departure, vessel: vessel, referenceNumber: referenceNumber, departureDate: nil)]
        )
    }

    func test_errorKey_beforeSubmit_isNil() {
        let sut = TripStartedTodayViewModel(vessel: vessel, referenceNumber: referenceNumber, router: CatchRecordRouter())
        XCTAssertNil(sut.errorKey)
    }
}
