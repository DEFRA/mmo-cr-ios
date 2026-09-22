import XCTest
@testable import record_catch

@MainActor
final class CatchRecordDraftTests: XCTestCase {

    func test_init_generatesUniqueLocalIDByDefault() {
        let first = CatchRecordDraft()
        let second = CatchRecordDraft()
        XCTAssertNotEqual(first.localID, second.localID)
    }

    func test_init_canBeSeededWithAnExplicitLocalID() {
        let localID = UUID()
        let sut = CatchRecordDraft(localID: localID)
        XCTAssertEqual(sut.localID, localID)
    }

    func test_payload_capturesEveryPersistedField() {
        let sut = CatchRecordDraft()
        sut.vessel = "ACHILLES"
        sut.departureDate = Date(timeIntervalSince1970: 1_000)
        sut.returnDate = Date(timeIntervalSince1970: 2_000)
        sut.departurePort = PortOption(name: "Hastings")
        sut.returnPort = PortOption(name: "Newlyn")
        sut.gearCatches = [GearCatch(gear: .seineNets, statisticalArea: "38E96", speciesCaught: [.atlanticCod])]
        sut.speciesNotLanded = [.atlanticCod]
        sut.advance(to: .ports)

        let payload = sut.payload

        XCTAssertEqual(payload.vessel, "ACHILLES")
        XCTAssertEqual(payload.departureDate, sut.departureDate)
        XCTAssertEqual(payload.returnDate, sut.returnDate)
        XCTAssertEqual(payload.departurePort, sut.departurePort)
        XCTAssertEqual(payload.returnPort, sut.returnPort)
        XCTAssertEqual(payload.gearCatches, sut.gearCatches)
        XCTAssertEqual(payload.speciesNotLanded, sut.speciesNotLanded)
        XCTAssertEqual(payload.checkpoint, .ports)
    }

    func test_apply_overwritesEveryPersistedField_inPlace() {
        let sut = CatchRecordDraft()
        sut.vessel = "OLD"
        let payload = CatchRecordDraftPayload(
            vessel: "ACHILLES",
            departureDate: Date(timeIntervalSince1970: 1_000),
            returnDate: Date(timeIntervalSince1970: 2_000),
            departurePort: PortOption(name: "Hastings"),
            returnPort: PortOption(name: "Newlyn"),
            gearCatches: [GearCatch(gear: .seineNets, statisticalArea: "38E96")],
            speciesNotLanded: [.atlanticCod],
            checkpoint: .gear
        )

        sut.apply(payload)

        XCTAssertEqual(sut.vessel, "ACHILLES")
        XCTAssertEqual(sut.departureDate, payload.departureDate)
        XCTAssertEqual(sut.returnDate, payload.returnDate)
        XCTAssertEqual(sut.departurePort, payload.departurePort)
        XCTAssertEqual(sut.returnPort, payload.returnPort)
        XCTAssertEqual(sut.gearCatches, payload.gearCatches)
        XCTAssertEqual(sut.speciesNotLanded, payload.speciesNotLanded)
        XCTAssertEqual(sut.checkpoint, .gear)
    }

    func test_payload_roundTripsThroughJSONEncoding() throws {
        let sut = CatchRecordDraft()
        sut.vessel = "ACHILLES"
        sut.gearCatches = [GearCatch(gear: .seineNets, statisticalArea: "38E96", speciesCaught: [.atlanticCod])]
        sut.advance(to: .checkYourAnswers)

        let data = try JSONEncoder().encode(sut.payload)
        let decoded = try JSONDecoder().decode(CatchRecordDraftPayload.self, from: data)

        XCTAssertEqual(decoded, sut.payload)
        XCTAssertEqual(decoded.checkpoint, .checkYourAnswers)
    }

    // MARK: - checkpoint (see ADR-0014 decision #5, amended — resume at the last completed section)

    func test_checkpoint_defaultsToVessel() {
        let sut = CatchRecordDraft()
        XCTAssertEqual(sut.checkpoint, .vessel)
    }

    func test_advance_movesCheckpointForward() {
        let sut = CatchRecordDraft()
        sut.advance(to: .ports)
        XCTAssertEqual(sut.checkpoint, .ports)
    }

    func test_advance_neverMovesCheckpointBackward() {
        let sut = CatchRecordDraft()
        sut.advance(to: .gear)
        sut.advance(to: .tripDates)
        XCTAssertEqual(sut.checkpoint, .gear)
    }

    func test_advance_toSameCheckpoint_isANoOp() {
        let sut = CatchRecordDraft()
        sut.advance(to: .ports)
        sut.advance(to: .ports)
        XCTAssertEqual(sut.checkpoint, .ports)
    }

    func test_checkpointDecoding_missingKey_defaultsToVessel_forAlreadyPersistedDrafts() throws {
        // Simulates a draft persisted before `checkpoint` existed on `CatchRecordDraftPayload`.
        let json = """
        {
            "vessel": "ACHILLES",
            "gearCatches": [],
            "speciesNotLanded": []
        }
        """
        let decoded = try JSONDecoder().decode(CatchRecordDraftPayload.self, from: Data(json.utf8))

        XCTAssertEqual(decoded.vessel, "ACHILLES")
        XCTAssertEqual(decoded.checkpoint, .vessel)
    }
}
