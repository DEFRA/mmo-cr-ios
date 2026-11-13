//
//  CatchRecordDTOsTests.swift
//  record-catchTests
//
//  Encode/decode tests for the Catch Recording Service wire types (ADR-0025): explicit-null
//  encoding for required-and-nullable fields, ISO 8601 dates with/without fractional seconds,
//  `CharacteristicValue`'s mixed-type decode, and the two same-object `allOf` responses.
//

import XCTest
@testable import record_catch

final class CatchRecordDTOsTests: XCTestCase {

    private func makeEncoder() -> JSONEncoder { CatchRecordTransport.makeEncoder() }
    private func makeDecoder() -> JSONDecoder { CatchRecordTransport.makeDecoder() }

    // MARK: PairFishingDTO — explicit null for required-and-nullable fields

    func test_pairFishingDTO_encodesExplicitNulls_whenDisabled() throws {
        let dto = PairFishingDTO(enabled: false)
        let data = try makeEncoder().encode(dto)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertTrue(json.keys.contains("pairVessel"))
        XCTAssertTrue(json.keys.contains("pairSkipperName"))
        XCTAssertTrue(json["pairVessel"] is NSNull)
        XCTAssertTrue(json["pairSkipperName"] is NSNull)
    }

    func test_pairFishingDTO_encodesValues_whenEnabled() throws {
        let dto = PairFishingDTO(enabled: true, pairVessel: "HERCULES", pairSkipperName: "J Smith")
        let data = try makeEncoder().encode(dto)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(json["pairVessel"] as? String, "HERCULES")
        XCTAssertEqual(json["pairSkipperName"] as? String, "J Smith")
    }

    // MARK: Dates — with and without fractional seconds

    func test_decoder_decodesDate_withFractionalSeconds() throws {
        let json = Data(#"{"value":"2026-11-11T10:00:00.123Z"}"#.utf8)
        struct Wrapper: Decodable { let value: Date }
        let wrapper = try makeDecoder().decode(Wrapper.self, from: json)

        let expectedFormatter = ISO8601DateFormatter()
        expectedFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let expected = try XCTUnwrap(expectedFormatter.date(from: "2026-11-11T10:00:00.123Z"))
        XCTAssertEqual(wrapper.value, expected)
    }

    func test_decoder_decodesDate_withoutFractionalSeconds() throws {
        let json = Data(#"{"value":"2026-11-11T10:00:00Z"}"#.utf8)
        struct Wrapper: Decodable { let value: Date }
        let wrapper = try makeDecoder().decode(Wrapper.self, from: json)

        let expectedFormatter = ISO8601DateFormatter()
        expectedFormatter.formatOptions = [.withInternetDateTime]
        let expected = try XCTUnwrap(expectedFormatter.date(from: "2026-11-11T10:00:00Z"))
        XCTAssertEqual(wrapper.value, expected)
    }

    func test_decoder_throwsDecodingError_forUnparsableDate() {
        let json = Data(#"{"value":"not-a-date"}"#.utf8)
        struct Wrapper: Decodable { let value: Date }
        XCTAssertThrowsError(try makeDecoder().decode(Wrapper.self, from: json))
    }

    // MARK: CharacteristicValue — mixed-type decode

    func test_characteristicValue_decodesNumberStringAndBool() throws {
        let decoder = makeDecoder()
        let numberJSON = Data(#"{"characteristicId":"c1","nameSnapshot":"Mesh size","value":100}"#.utf8)
        let stringJSON = Data(#"{"characteristicId":"c1","nameSnapshot":"Colour","value":"red"}"#.utf8)
        let boolJSON = Data(#"{"characteristicId":"c1","nameSnapshot":"Powered","value":true}"#.utf8)

        XCTAssertEqual(try decoder.decode(CharacteristicDTO.self, from: numberJSON).value, .number(100))
        XCTAssertEqual(try decoder.decode(CharacteristicDTO.self, from: stringJSON).value, .string("red"))
        XCTAssertEqual(try decoder.decode(CharacteristicDTO.self, from: boolJSON).value, .bool(true))
    }

    func test_characteristicValue_roundTripsThroughEncodeDecode() throws {
        let original = CharacteristicDTO(characteristicId: "c1", nameSnapshot: "Mesh size", value: .number(80), unitSnapshot: "mm")
        let data = try makeEncoder().encode(original)
        let decoded = try makeDecoder().decode(CharacteristicDTO.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    // MARK: SectionPatchPayload — wire shape

    func test_sectionPatchPayload_encodesSectionAndData_forEachCase() throws {
        let encoder = makeEncoder()

        let tripData = try encoder.encode(SectionPatchPayload.trip(
            TripDTO(startedAndFinishedToday: true, dateStarted: "2026-11-11", dateEnded: "2026-11-11",
                    departurePort: CatchRecordPortDTO(id: "p", codeSnapshot: "C", nameSnapshot: "N"),
                    returnPort: CatchRecordPortDTO(id: "p", codeSnapshot: "C", nameSnapshot: "N"))
        ))
        let tripJSON = try XCTUnwrap(JSONSerialization.jsonObject(with: tripData) as? [String: Any])
        XCTAssertEqual(tripJSON["section"] as? String, "trip")
        XCTAssertNotNil(tripJSON["data"])

        let gearsData = try encoder.encode(SectionPatchPayload.gears([]))
        let gearsJSON = try XCTUnwrap(JSONSerialization.jsonObject(with: gearsData) as? [String: Any])
        XCTAssertEqual(gearsJSON["section"] as? String, "gears")
        XCTAssertEqual(gearsJSON["data"] as? [String], [])

        let pairFishingData = try encoder.encode(SectionPatchPayload.pairFishing(PairFishingDTO(enabled: false)))
        let pairFishingJSON = try XCTUnwrap(JSONSerialization.jsonObject(with: pairFishingData) as? [String: Any])
        XCTAssertEqual(pairFishingJSON["section"] as? String, "pairFishing")
        XCTAssertNotNil(pairFishingJSON["data"])

        let speciesData = try encoder.encode(SectionPatchPayload.speciesNotLanded([]))
        let speciesJSON = try XCTUnwrap(JSONSerialization.jsonObject(with: speciesData) as? [String: Any])
        XCTAssertEqual(speciesJSON["section"] as? String, "speciesNotLanded")
        XCTAssertEqual(speciesJSON["data"] as? [String], [])
    }

    // MARK: Same-object `allOf` responses

    func test_submissionResponseDTO_decodesBaseAndExtraFieldsFromSameObject() throws {
        let json = Data("""
        {
          "id": "cr-1",
          "catchRecordReference": "A12345-11112026-100000",
          "status": "SUBMITTED",
          "displayStatus": "Submitted",
          "version": 2,
          "savedSection": null,
          "sectionCompletion": { "trip": true, "pairFishing": true, "gears": true },
          "progress": {
            "hasUnsubmittedChanges": false,
            "numberOfSubmissions": 1,
            "incompleteGearAssociationIds": [],
            "currentIncompleteGearAssociationId": null,
            "allGearsComplete": true
          },
          "submittedAt": "2026-11-11T10:00:00Z",
          "submittedBy": "user-1",
          "artifacts": [{ "submissionNumber": 1, "type": "PDF_RECEIPT" }]
        }
        """.utf8)

        let response = try makeDecoder().decode(SubmissionResponseDTO.self, from: json)

        XCTAssertEqual(response.standard.id, "cr-1")
        XCTAssertEqual(response.standard.status, .submitted)
        XCTAssertNil(response.standard.savedSection)
        XCTAssertEqual(response.submittedBy, "user-1")
        XCTAssertEqual(response.artifacts.first?.type, .pdfReceipt)
    }

    func test_retrieveCatchRecordResponseDTO_decodesCanonicalRecordAndOverlayFields() throws {
        let json = Data("""
        {
          "schemaVersion": 1,
          "id": "cr-1",
          "catchRecordReference": "A12345-11112026-100000",
          "ownerUserId": "owner-1",
          "status": "DRAFT",
          "version": 1,
          "numberOfSubmissions": 0,
          "hasUnsubmittedChanges": true,
          "vessel": { "id": "v1", "rssSnapshot": "A12345", "nameSnapshot": "ACHILLES", "externalMarkSnapshot": "AH1" },
          "trip": {
            "startedAndFinishedToday": true, "dateStarted": "2026-11-11", "dateEnded": "2026-11-11",
            "departurePort": { "id": "p1", "codeSnapshot": "GBPLY", "nameSnapshot": "Plymouth" },
            "returnPort": { "id": "p1", "codeSnapshot": "GBPLY", "nameSnapshot": "Plymouth" }
          },
          "pairFishing": { "enabled": false, "pairVessel": null, "pairSkipperName": null },
          "gears": [],
          "speciesNotLanded": [],
          "artifacts": [],
          "createdAt": "2026-11-11T09:00:00Z",
          "createdBy": "owner-1",
          "updatedAt": "2026-11-11T09:30:00Z",
          "updatedBy": "owner-1",
          "submittedAt": null,
          "submittedBy": null,
          "completedAt": null,
          "completedBy": null,
          "displayStatus": "Draft",
          "sectionCompletion": { "trip": true, "pairFishing": true, "gears": false },
          "completedSections": ["trip", "pairFishing"],
          "incompleteSections": ["gears"],
          "progress": {
            "hasUnsubmittedChanges": true,
            "numberOfSubmissions": 0,
            "incompleteGearAssociationIds": [],
            "currentIncompleteGearAssociationId": null,
            "allGearsComplete": false
          },
          "submissionEligible": false
        }
        """.utf8)

        let response = try makeDecoder().decode(RetrieveCatchRecordResponseDTO.self, from: json)

        XCTAssertEqual(response.record.id, "cr-1")
        XCTAssertEqual(response.record.vessel.rssSnapshot, "A12345")
        XCTAssertNil(response.record.submittedAt)
        XCTAssertEqual(response.displayStatus, .draft)
        XCTAssertEqual(response.completedSections, [.trip, .pairFishing])
        XCTAssertFalse(response.submissionEligible)
    }

    func test_decoder_throws_forUnknownStatusValue() {
        let json = Data(#"{"value":"NOT_A_REAL_STATUS"}"#.utf8)
        struct Wrapper: Decodable { let value: PersistedCatchRecordStatus }
        XCTAssertThrowsError(try makeDecoder().decode(Wrapper.self, from: json))
    }

    // MARK: Same-object `allOf` responses — encode round-trips

    func test_submissionResponseDTO_encode_roundTripsThroughDecode() throws {
        let json = Data("""
        {
          "id": "cr-1",
          "catchRecordReference": "A12345-11112026-100000",
          "status": "SUBMITTED",
          "displayStatus": "Submitted",
          "version": 2,
          "savedSection": null,
          "sectionCompletion": { "trip": true, "pairFishing": true, "gears": true },
          "progress": {
            "hasUnsubmittedChanges": false,
            "numberOfSubmissions": 1,
            "incompleteGearAssociationIds": [],
            "currentIncompleteGearAssociationId": null,
            "allGearsComplete": true
          },
          "submittedAt": "2026-11-11T10:00:00Z",
          "submittedBy": "user-1",
          "artifacts": [{ "submissionNumber": 1, "type": "PDF_RECEIPT" }]
        }
        """.utf8)
        let original = try makeDecoder().decode(SubmissionResponseDTO.self, from: json)

        let data = try makeEncoder().encode(original)
        let decoded = try makeDecoder().decode(SubmissionResponseDTO.self, from: data)

        XCTAssertEqual(decoded.standard, original.standard)
        XCTAssertEqual(decoded.submittedBy, "user-1")
        XCTAssertEqual(decoded.artifacts, original.artifacts)
    }

    func test_retrieveCatchRecordResponseDTO_encode_roundTripsThroughDecode() throws {
        let json = Data("""
        {
          "schemaVersion": 1,
          "id": "cr-1",
          "catchRecordReference": "A12345-11112026-100000",
          "ownerUserId": "owner-1",
          "status": "DRAFT",
          "version": 1,
          "numberOfSubmissions": 0,
          "hasUnsubmittedChanges": true,
          "vessel": { "id": "v1", "rssSnapshot": "A12345", "nameSnapshot": "ACHILLES", "externalMarkSnapshot": "AH1" },
          "trip": {
            "startedAndFinishedToday": true, "dateStarted": "2026-11-11", "dateEnded": "2026-11-11",
            "departurePort": { "id": "p1", "codeSnapshot": "GBPLY", "nameSnapshot": "Plymouth" },
            "returnPort": { "id": "p1", "codeSnapshot": "GBPLY", "nameSnapshot": "Plymouth" }
          },
          "pairFishing": { "enabled": false, "pairVessel": null, "pairSkipperName": null },
          "gears": [],
          "speciesNotLanded": [],
          "artifacts": [],
          "createdAt": "2026-11-11T09:00:00Z",
          "createdBy": "owner-1",
          "updatedAt": "2026-11-11T09:30:00Z",
          "updatedBy": "owner-1",
          "submittedAt": null,
          "submittedBy": null,
          "completedAt": null,
          "completedBy": null,
          "displayStatus": "Draft",
          "sectionCompletion": { "trip": true, "pairFishing": true, "gears": false },
          "completedSections": ["trip", "pairFishing"],
          "incompleteSections": ["gears"],
          "progress": {
            "hasUnsubmittedChanges": true,
            "numberOfSubmissions": 0,
            "incompleteGearAssociationIds": [],
            "currentIncompleteGearAssociationId": null,
            "allGearsComplete": false
          },
          "submissionEligible": false
        }
        """.utf8)
        let original = try makeDecoder().decode(RetrieveCatchRecordResponseDTO.self, from: json)

        let data = try makeEncoder().encode(original)
        let decoded = try makeDecoder().decode(RetrieveCatchRecordResponseDTO.self, from: data)

        XCTAssertEqual(decoded.record, original.record)
        XCTAssertEqual(decoded.displayStatus, .draft)
        XCTAssertEqual(decoded.completedSections, [.trip, .pairFishing])
        XCTAssertFalse(decoded.submissionEligible)
    }

    // MARK: Request payloads with custom convenience initialisers

    func test_createDraftCatchRecordPayload_defaultsReferenceToNil() throws {
        let payload = CreateDraftCatchRecordPayload(vesselId: "v1")

        XCTAssertNil(payload.catchRecordReference)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: try makeEncoder().encode(payload)) as? [String: Any])
        XCTAssertEqual(json["vesselId"] as? String, "v1")
    }

    func test_gearAssociationDTO_defaultsCollectionsToEmpty() {
        let association = GearAssociationDTO(associationId: "a1", gear: GearSnapshotDTO(id: "g1", codeSnapshot: "GN", nameSnapshot: "Gill net"))

        XCTAssertTrue(association.characteristics.isEmpty)
        XCTAssertNil(association.statisticalArea)
        XCTAssertTrue(association.speciesCaught.isEmpty)
    }

    func test_speciesWeightEntryDTO_defaultsOptionalWeightsToNil() {
        let entry = SpeciesWeightEntryDTO(id: "s1", faoCodeSnapshot: "COD", nameSnapshot: "Cod")

        XCTAssertNil(entry.weightAboveMinimumKg)
        XCTAssertNil(entry.weightBelowMinimumKg)
        XCTAssertNil(entry.weightLegallyDiscardedKg)
        XCTAssertNil(entry.weightPrecision)
    }

    func test_completeReplacementPayload_encodesAndDecodes() throws {
        let original = CompleteReplacementPayload(
            vessel: VesselSnapshotDTO(id: "v1", rssSnapshot: "A12345", nameSnapshot: "ACHILLES", externalMarkSnapshot: "AH1", lengthOverallMetresSnapshot: 9.5),
            trip: TripDTO(
                startedAndFinishedToday: true, dateStarted: "2026-11-11", dateEnded: "2026-11-11",
                departurePort: CatchRecordPortDTO(id: "p1", codeSnapshot: "GBPLY", nameSnapshot: "Plymouth"),
                returnPort: CatchRecordPortDTO(id: "p1", codeSnapshot: "GBPLY", nameSnapshot: "Plymouth")
            ),
            pairFishing: PairFishingDTO(enabled: false),
            gears: [],
            speciesNotLanded: []
        )

        let data = try makeEncoder().encode(original)
        let decoded = try makeDecoder().decode(CompleteReplacementPayload.self, from: data)

        XCTAssertEqual(decoded, original)
    }
}
