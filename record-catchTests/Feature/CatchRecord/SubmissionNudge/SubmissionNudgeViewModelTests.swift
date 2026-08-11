import XCTest
@testable import record_catch

@MainActor
final class SubmissionNudgeViewModelTests: XCTestCase {

    private let vessel = "ACHILLES"
    private let referenceNumber = "A1234520260727150815"

    func test_initialState_exposesInputs() {
        let sut = SubmissionNudgeViewModel(
            daysLate: 3,
            vessel: vessel,
            referenceNumber: referenceNumber,
            router: CatchRecordRouter()
        )
        XCTAssertEqual(sut.daysLate, 3)
        XCTAssertEqual(sut.vessel, vessel)
        XCTAssertEqual(sut.referenceNumber, referenceNumber)
    }

    // MARK: - checkTripEndDate

    func test_checkTripEndDate_popsBack() {
        let router = CatchRecordRouter()
        router.push(.tripDate(phase: .return, vessel: vessel, referenceNumber: referenceNumber, departureDate: nil))
        router.push(.submissionNudge(daysLate: 3, vessel: vessel, referenceNumber: referenceNumber))
        let sut = SubmissionNudgeViewModel(daysLate: 3, vessel: vessel, referenceNumber: referenceNumber, router: router)

        sut.checkTripEndDate()

        XCTAssertEqual(
            router.path,
            [.tripDate(phase: .return, vessel: vessel, referenceNumber: referenceNumber, departureDate: nil)]
        )
    }

    // MARK: - continue → port sub-journey

    func test_enterPortSubJourney_withNoFavourites_pushesAddPort() async {
        let router = CatchRecordRouter()
        let sut = SubmissionNudgeViewModel(
            daysLate: 3,
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
        let sut = SubmissionNudgeViewModel(
            daysLate: 3,
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
}
