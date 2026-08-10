import XCTest
@testable import record_catch

@MainActor
final class TripDateViewModelTests: XCTestCase {

    private let vessel = "ACHILLES"
    private let referenceNumber = "A1234520260727150815"

    private func makeValidDate() -> DateEntryValue {
        DateEntryValue(day: "31", month: "03", year: "2020")
    }

    // MARK: - Initial state

    func test_initialState_hasNoErrorAndExposesPhaseCopy() {
        let sut = TripDateViewModel(
            phase: .departure,
            vessel: vessel,
            referenceNumber: referenceNumber,
            departureDate: nil,
            router: CatchRecordRouter()
        )
        XCTAssertNil(sut.errorKey)
        XCTAssertEqual(sut.referenceNumber, referenceNumber)
        XCTAssertEqual(sut.vessel, vessel)
        XCTAssertEqual(sut.titleKey, "catchRecord.tripDate.departure.title")
        XCTAssertEqual(sut.hintKey, "catchRecord.tripDate.departure.hint")
    }

    func test_returnPhase_exposesReturnCopy() {
        let sut = TripDateViewModel(
            phase: .return,
            vessel: vessel,
            referenceNumber: referenceNumber,
            departureDate: Date(),
            router: CatchRecordRouter()
        )
        XCTAssertEqual(sut.titleKey, "catchRecord.tripDate.return.title")
        XCTAssertEqual(sut.hintKey, "catchRecord.tripDate.return.hint")
    }

    // MARK: - Submit: failure

    func test_submit_withInvalidDate_setsError_andDoesNotRoute() {
        let router = CatchRecordRouter()
        let sut = TripDateViewModel(
            phase: .departure,
            vessel: vessel,
            referenceNumber: referenceNumber,
            departureDate: nil,
            router: router
        )

        sut.submit()

        XCTAssertEqual(sut.errorKey, "catchRecord.tripDate.validation.none")
        XCTAssertTrue(router.path.isEmpty)
    }

    // MARK: - Submit: departure success

    func test_submit_departure_withValidDate_pushesReturnCarryingDepartureDate() {
        let router = CatchRecordRouter()
        let sut = TripDateViewModel(
            phase: .departure,
            vessel: vessel,
            referenceNumber: referenceNumber,
            departureDate: nil,
            router: router
        )
        sut.value = makeValidDate()

        sut.submit()

        XCTAssertNil(sut.errorKey)
        let expectedDate = DateEntryField.parsedDate(from: makeValidDate())
        XCTAssertEqual(
            router.path,
            [.tripDate(phase: .return, vessel: vessel, referenceNumber: referenceNumber, departureDate: expectedDate)]
        )
    }

    // MARK: - Submit: return success (enters port sub-journey)

    func test_enterPortSubJourney_return_withNoFavourites_pushesAddPort() async {
        let router = CatchRecordRouter()
        let sut = TripDateViewModel(
            phase: .return,
            vessel: vessel,
            referenceNumber: referenceNumber,
            departureDate: Date(),
            router: router,
            favouritePorts: StubFavouritePortsProvider()
        )

        await sut.enterPortSubJourney()

        XCTAssertEqual(
            router.path,
            [.addPort(vessel: vessel, referenceNumber: referenceNumber, returnPhase: nil)]
        )
    }

    func test_enterPortSubJourney_return_withFavourites_pushesSelectDeparture() async {
        let router = CatchRecordRouter()
        let sut = TripDateViewModel(
            phase: .return,
            vessel: vessel,
            referenceNumber: referenceNumber,
            departureDate: Date(),
            router: router,
            favouritePorts: StubFavouritePortsProvider(initialFavourites: [PortOption(name: "Hastings")])
        )

        await sut.enterPortSubJourney()

        XCTAssertEqual(
            router.path,
            [.selectPort(phase: .departure, vessel: vessel, referenceNumber: referenceNumber)]
        )
    }

    func test_errorKey_beforeSubmit_isNil() {
        let sut = TripDateViewModel(
            phase: .departure,
            vessel: vessel,
            referenceNumber: referenceNumber,
            departureDate: nil,
            router: CatchRecordRouter()
        )
        sut.value = DateEntryValue()
        XCTAssertNil(sut.errorKey)
    }
}
