import XCTest
@testable import record_catch

@MainActor
final class CatchRecordRoutingTests: XCTestCase {

    func test_entryRoute_forUnsentRow_returnsDraftActionRoute() {
        let row = record_catch.SubmissionRow(dateText: "20 Nov 2020", vesselName: "ACHILLES", status: .unsent, createdBy: "J.Smith")

        XCTAssertEqual(CatchRecordRouting.entryRoute(for: row), .draftAction(row))
    }

    func test_entryRoute_forSubmittedRow_returnsNil() {
        let row = record_catch.SubmissionRow(dateText: "20 Nov 2020", vesselName: "ACHILLES", status: .submitted, createdBy: "J.Smith")

        XCTAssertNil(CatchRecordRouting.entryRoute(for: row))
    }

    func test_entryRoute_forAmendedRow_returnsNil() {
        let row = record_catch.SubmissionRow(dateText: "20 Nov 2020", vesselName: "ACHILLES", status: .amended, createdBy: "J.Smith")

        XCTAssertNil(CatchRecordRouting.entryRoute(for: row))
    }

    func test_entryRoute_forLateRow_returnsNil() {
        let row = record_catch.SubmissionRow(dateText: "20 Nov 2020", vesselName: "ACHILLES", status: .late, createdBy: "J.Smith")

        XCTAssertNil(CatchRecordRouting.entryRoute(for: row))
    }

    // MARK: - Port entry decision

    func test_portEntryRoute_withNoFavourites_returnsAddPortWithNilReturnPhase() {
        let route = CatchRecordRouting.portEntryRoute(
            hasFavourites: false,
            vessel: "ACHILLES",
            referenceNumber: "REF"
        )

        XCTAssertEqual(route, .addPort(vessel: "ACHILLES", referenceNumber: "REF", returnPhase: nil))
    }

    func test_portEntryRoute_withFavourites_returnsSelectDeparturePort() {
        let route = CatchRecordRouting.portEntryRoute(
            hasFavourites: true,
            vessel: "ACHILLES",
            referenceNumber: "REF"
        )

        XCTAssertEqual(route, .selectPort(phase: .departure, vessel: "ACHILLES", referenceNumber: "REF"))
    }

    // MARK: - Gear entry decision

    func test_gearEntryRoute_withNoFavourites_returnsAddGear() {
        let route = CatchRecordRouting.gearEntryRoute(hasFavourites: false, vessel: "ACHILLES", referenceNumber: "REF")
        XCTAssertEqual(route, .addGear(vessel: "ACHILLES", referenceNumber: "REF"))
    }

    func test_gearEntryRoute_withFavourites_returnsSelectGear() {
        let route = CatchRecordRouting.gearEntryRoute(hasFavourites: true, vessel: "ACHILLES", referenceNumber: "REF")
        XCTAssertEqual(route, .selectGear(vessel: "ACHILLES", referenceNumber: "REF"))
    }

    // MARK: - Species completion decision (multi-gear loop — see ADR-0011)

    func test_speciesCompletionRoute_forSingleGear_returnsLandingStorage() {
        let seineNets = GearOption.seineNets
        let route = CatchRecordRouting.speciesCompletionRoute(
            currentGearID: seineNets.id,
            orderedGears: [seineNets],
            vessel: "ACHILLES",
            referenceNumber: "REF",
            resumingAtCheckYourAnswers: false
        )
        XCTAssertEqual(route, .landingStorage(referenceNumber: "REF"))
    }

    func test_speciesCompletionRoute_forFirstOfMultipleGears_loopsToCatchLocationForNextGear() {
        let seineNets = GearOption.seineNets
        let trawl = GearOption(name: "Trawl nets")
        let route = CatchRecordRouting.speciesCompletionRoute(
            currentGearID: seineNets.id,
            orderedGears: [seineNets, trawl],
            vessel: "ACHILLES",
            referenceNumber: "REF",
            resumingAtCheckYourAnswers: false
        )
        XCTAssertEqual(route, .catchLocation(gear: trawl, vessel: "ACHILLES", referenceNumber: "REF"))
    }

    func test_speciesCompletionRoute_forMiddleOfMultipleGears_loopsToCatchLocationForNextGear() {
        let first = GearOption(name: "Gear A")
        let middle = GearOption(name: "Gear B")
        let last = GearOption(name: "Gear C")
        let route = CatchRecordRouting.speciesCompletionRoute(
            currentGearID: middle.id,
            orderedGears: [first, middle, last],
            vessel: "ACHILLES",
            referenceNumber: "REF",
            resumingAtCheckYourAnswers: false
        )
        XCTAssertEqual(route, .catchLocation(gear: last, vessel: "ACHILLES", referenceNumber: "REF"))
    }

    func test_speciesCompletionRoute_forLastOfMultipleGears_returnsLandingStorage() {
        let seineNets = GearOption.seineNets
        let trawl = GearOption(name: "Trawl nets")
        let route = CatchRecordRouting.speciesCompletionRoute(
            currentGearID: trawl.id,
            orderedGears: [seineNets, trawl],
            vessel: "ACHILLES",
            referenceNumber: "REF",
            resumingAtCheckYourAnswers: false
        )
        XCTAssertEqual(route, .landingStorage(referenceNumber: "REF"))
    }

    func test_speciesCompletionRoute_forUnknownGear_returnsLandingStorage() {
        let route = CatchRecordRouting.speciesCompletionRoute(
            currentGearID: "unknown",
            orderedGears: [.seineNets],
            vessel: "ACHILLES",
            referenceNumber: "REF",
            resumingAtCheckYourAnswers: false
        )
        XCTAssertEqual(route, .landingStorage(referenceNumber: "REF"))
    }

    func test_speciesCompletionRoute_whenResumingAtCheckYourAnswers_returnsThereEvenWithMoreGearsRemaining() {
        let seineNets = GearOption.seineNets
        let trawl = GearOption(name: "Trawl nets")
        let route = CatchRecordRouting.speciesCompletionRoute(
            currentGearID: seineNets.id,
            orderedGears: [seineNets, trawl],
            vessel: "ACHILLES",
            referenceNumber: "REF",
            resumingAtCheckYourAnswers: true
        )
        XCTAssertEqual(route, .checkYourAnswers(referenceNumber: "REF"))
    }
}
