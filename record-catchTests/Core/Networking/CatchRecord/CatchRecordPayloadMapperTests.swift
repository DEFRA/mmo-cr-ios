//
//  CatchRecordPayloadMapperTests.swift
//  record-catchTests
//
//  Covers `CatchRecordPayloadMapper.map(payload:vesselProvider:)` — the happy path and every
//  typed `CatchRecordMappingError` case (ADR-0025/ADR-0028). Core business logic requires >=95%
//  coverage (testing.instructions.md).
//

import XCTest
@testable import record_catch

final class CatchRecordPayloadMapperTests: XCTestCase {

    private let achilles = VesselOption(
        id: "A12345", name: "ACHILLES", registrationNumber: "A12345"
    )

    private func makeCompletePayload() -> CatchRecordDraftPayload {
        CatchRecordDraftPayload(
            vessel: "ACHILLES",
            catchRecordReference: "A12345-11112026-100000",
            departureDate: Date(timeIntervalSince1970: 1_700_000_000),
            returnDate: Date(timeIntervalSince1970: 1_700_086_400),
            departurePort: PortOption(id: "p-ply", name: "Plymouth", coordinate: nil, code: "GBPLY", countryCode: "GBR", isActive: true),
            returnPort: PortOption(id: "p-new", name: "Newlyn", coordinate: nil, code: "GBNEW", countryCode: "GBR", isActive: true),
            gearCatches: [
                GearCatch(
                    gear: GearOption(
                        id: "seine-nets",
                        name: "Seine nets",
                        requiredMeasurements: [GearMeasurement(id: "meshSize", labelKey: "k", value: 80, apiCode: "MESH_SIZE")]
                    ),
                    statisticalArea: "27.7.e",
                    speciesCaught: [SpeciesOption(id: "cod", name: "Atlantic cod (COD)", weights: .init(aboveMinimumKg: "250"))]
                )
            ],
            speciesNotLanded: [SpeciesOption(id: "cod", name: "Atlantic cod (COD)", weights: .init(aboveMinimumKg: "5"))]
        )
    }

    // MARK: Happy path

    func test_map_withEveryFieldCaptured_producesTheExpectedReplacementPayload() throws {
        let replacement = try CatchRecordPayloadMapper.map(payload: makeCompletePayload(), vessel: achilles)

        XCTAssertEqual(replacement.vessel.id, "A12345")
        XCTAssertEqual(replacement.vessel.nameSnapshot, "ACHILLES")
        XCTAssertEqual(replacement.vessel.rssSnapshot, "A12345")
        XCTAssertEqual(replacement.trip.dateStarted, "2023-11-14")
        XCTAssertEqual(replacement.trip.dateEnded, "2023-11-15")
        XCTAssertEqual(replacement.trip.departurePort.nameSnapshot, "Plymouth")
        XCTAssertEqual(replacement.trip.returnPort.nameSnapshot, "Newlyn")
        XCTAssertFalse(replacement.trip.startedAndFinishedToday)
        XCTAssertEqual(replacement.gears.count, 1)
        XCTAssertEqual(replacement.gears[0].statisticalArea?.id, "27.7.e")
        XCTAssertEqual(replacement.gears[0].speciesCaught.first?.weightAboveMinimumKg, 250)
        XCTAssertEqual(replacement.gears[0].characteristics.first?.characteristicId, "MESH_SIZE")
        XCTAssertEqual(replacement.speciesNotLanded.first?.weightAboveMinimumKg, 5)
    }

    func test_map_whenDepartureAndReturnAreTheSameDay_setsStartedAndFinishedToday() throws {
        var payload = makeCompletePayload()
        payload.returnDate = payload.departureDate
        let replacement = try CatchRecordPayloadMapper.map(payload: payload, vessel: achilles)
        XCTAssertTrue(replacement.trip.startedAndFinishedToday)
    }

    // MARK: Every CatchRecordMappingError case — every one is a permanent, non-retryable failure

    func test_map_throwsMissingVessel_whenNoVesselCaptured() {
        var payload = makeCompletePayload()
        payload.vessel = nil
        XCTAssertThrowsError(try CatchRecordPayloadMapper.map(payload: payload, vessel: achilles)) {
            XCTAssertEqual($0 as? CatchRecordMappingError, .missingVessel)
            XCTAssertEqual(($0 as? CatchRecordMappingError)?.errorCode, "mapping_missing_vessel")
        }
    }

    func test_map_throwsMissingVesselDetails_whenVesselCouldNotBeResolved() {
        let payload = makeCompletePayload()
        XCTAssertThrowsError(try CatchRecordPayloadMapper.map(payload: payload, vessel: nil)) {
            XCTAssertEqual($0 as? CatchRecordMappingError, .missingVesselDetails)
            XCTAssertEqual(($0 as? CatchRecordMappingError)?.errorCode, "mapping_missing_vessel_details")
        }
    }

    func test_map_throwsMissingVesselDetails_whenVesselHasNoRSSNumber() {
        let payload = makeCompletePayload()
        let vesselWithNoRSSNumber = VesselOption(id: "v-1", name: "ACHILLES")
        XCTAssertThrowsError(try CatchRecordPayloadMapper.map(payload: payload, vessel: vesselWithNoRSSNumber)) {
            XCTAssertEqual($0 as? CatchRecordMappingError, .missingVesselDetails)
        }
    }

    func test_map_throwsMissingTripDates_whenDepartureDateIsNil() {
        var payload = makeCompletePayload()
        payload.departureDate = nil
        XCTAssertThrowsError(try CatchRecordPayloadMapper.map(payload: payload, vessel: achilles)) {
            XCTAssertEqual($0 as? CatchRecordMappingError, .missingTripDates)
        }
    }

    func test_map_throwsMissingTripDates_whenReturnDateIsNil() {
        var payload = makeCompletePayload()
        payload.returnDate = nil
        XCTAssertThrowsError(try CatchRecordPayloadMapper.map(payload: payload, vessel: achilles)) {
            XCTAssertEqual($0 as? CatchRecordMappingError, .missingTripDates)
        }
    }

    func test_map_throwsMissingPorts_whenDeparturePortIsNil() {
        var payload = makeCompletePayload()
        payload.departurePort = nil
        XCTAssertThrowsError(try CatchRecordPayloadMapper.map(payload: payload, vessel: achilles)) {
            XCTAssertEqual($0 as? CatchRecordMappingError, .missingPorts)
        }
    }

    func test_map_throwsMissingPorts_whenReturnPortIsNil() {
        var payload = makeCompletePayload()
        payload.returnPort = nil
        XCTAssertThrowsError(try CatchRecordPayloadMapper.map(payload: payload, vessel: achilles)) {
            XCTAssertEqual($0 as? CatchRecordMappingError, .missingPorts)
        }
    }

    func test_map_throwsMissingGear_whenNoGearCatchesRecorded() {
        var payload = makeCompletePayload()
        payload.gearCatches = []
        XCTAssertThrowsError(try CatchRecordPayloadMapper.map(payload: payload, vessel: achilles)) {
            XCTAssertEqual($0 as? CatchRecordMappingError, .missingGear)
        }
    }

    func test_map_throwsMissingStatisticalArea_whenAGearCatchHasNoStatisticalArea() {
        var payload = makeCompletePayload()
        payload.gearCatches[0].statisticalArea = nil
        XCTAssertThrowsError(try CatchRecordPayloadMapper.map(payload: payload, vessel: achilles)) {
            XCTAssertEqual($0 as? CatchRecordMappingError, .missingStatisticalArea(gearID: "seine-nets"))
            XCTAssertEqual(($0 as? CatchRecordMappingError)?.errorCode, "mapping_missing_statistical_area")
        }
    }
}
