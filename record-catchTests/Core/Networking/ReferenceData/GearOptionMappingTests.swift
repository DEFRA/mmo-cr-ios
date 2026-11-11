//
//  GearOptionMappingTests.swift
//  record-catchTests
//
//  Covers `GearOption.make(canonical:mobile:measurementsById:vesselLengthBand:)` — the join of a
//  gear's canonical-view record (the source of the required/per-trip split via
//  `applicableCharacteristics.fixed`) with its mobile-view record and measurements catalogue (see
//  ADR-0024 "Gears from two requests"). End-to-end decoding + the two-response join through
//  `RemoteReferenceDataClient.fetchGears()` is covered in `ReferenceDataClientGearsTests.swift`;
//  this file isolates the mapping function's own edge cases.
//

import XCTest
@testable import record_catch

final class GearOptionMappingTests: XCTestCase {

    private func makeMeasurementDefinition(
        id: String = "mesh-size",
        code: String? = "ME",
        label: String = "Mesh size (mm)",
        unit: String? = "mm"
    ) -> GearMeasurementDefinitionDTO {
        GearMeasurementDefinitionDTO(
            id: id,
            code: code,
            label: label,
            kind: "required",
            unit: unit,
            minimumValue: nil,
            maximumValue: nil
        )
    }

    private func makeCharacteristic(
        characteristicId: String,
        fixed: Bool,
        vesselLengthApplicability: [String]? = ["under-10m"]
    ) -> GearCharacteristicDTO {
        GearCharacteristicDTO(
            id: "c-\(characteristicId)",
            characteristicId: characteristicId,
            fixed: fixed,
            required: false,
            vesselLengthApplicability: vesselLengthApplicability
        )
    }

    private func makeCanonical(
        id: String = "1",
        code: String = "TBB",
        name: String = "Beam trawl",
        categoryId: String? = "c1",
        pairFishing: Bool? = false,
        applicableCharacteristics: [GearCharacteristicDTO]? = [],
        active: Bool? = true
    ) -> GearCanonicalDTO {
        GearCanonicalDTO(
            id: id,
            code: code,
            name: name,
            categoryId: categoryId,
            pairFishing: pairFishing,
            applicableCharacteristics: applicableCharacteristics,
            active: active
        )
    }

    private func makeMobile(
        id: String = "1",
        code: String = "TBB",
        name: String = "Beam trawl",
        category: GearCategoryDTO? = GearCategoryDTO(id: "c1", code: "TRAWL_NETS", name: "Trawl nets"),
        pairFishing: Bool? = false
    ) -> GearMobileDTO {
        GearMobileDTO(
            id: id,
            code: code,
            name: name,
            category: category,
            pairFishing: pairFishing,
            requiredMeasurementIds: nil,
            variableMeasurementIds: nil
        )
    }

    // MARK: Full mapping

    func test_make_mapsIdToTheAPICode_notTheGUID() throws {
        let canonical = makeCanonical(id: "guid-1", code: "TBB")
        let mobile = makeMobile(id: "guid-1", code: "TBB")

        let gear = try GearOption.make(canonical: canonical, mobile: mobile, measurementsById: [:])

        XCTAssertEqual(gear.id, "TBB", "Favourites are keyed on the FAO gear code, not the API GUID")
        XCTAssertEqual(gear.referenceId, "guid-1")
    }

    func test_make_mapsCategoryAndPairFishing_fromTheMobileRecord() throws {
        let canonical = makeCanonical(pairFishing: false)
        let mobile = makeMobile(
            category: GearCategoryDTO(id: "c1", code: "TRAWL_NETS", name: "Trawl nets"),
            pairFishing: true
        )

        let gear = try GearOption.make(canonical: canonical, mobile: mobile, measurementsById: [:])

        XCTAssertEqual(gear.categoryCode, "TRAWL_NETS")
        XCTAssertEqual(gear.categoryName, "Trawl nets")
        XCTAssertEqual(gear.isPairFishing, true, "mobile.pairFishing takes precedence over canonical's")
    }

    func test_make_fallsBackToCanonicalPairFishing_whenMobileOmitsIt() throws {
        let canonical = makeCanonical(pairFishing: true)
        let mobile = makeMobile(pairFishing: nil)

        let gear = try GearOption.make(canonical: canonical, mobile: mobile, measurementsById: [:])

        XCTAssertEqual(gear.isPairFishing, true)
    }

    func test_make_splitsFixedAndVariableCharacteristics_intoRequiredAndVariableMeasurements() throws {
        let canonical = makeCanonical(applicableCharacteristics: [
            makeCharacteristic(characteristicId: "mesh-size", fixed: true),
            makeCharacteristic(characteristicId: "times-shot", fixed: false)
        ])
        let mobile = makeMobile()
        let measurementsById = [
            "mesh-size": makeMeasurementDefinition(id: "mesh-size", code: "ME", label: "Mesh size (mm)", unit: "mm"),
            "times-shot": makeMeasurementDefinition(
                id: "times-shot",
                code: "TS",
                label: "Number of times the gear was shot",
                unit: "count"
            )
        ]

        let gear = try GearOption.make(canonical: canonical, mobile: mobile, measurementsById: measurementsById)

        XCTAssertEqual(gear.requiredMeasurements.map(\.id), ["mesh-size"])
        XCTAssertEqual(gear.requiredMeasurements[0].labelKey, "Mesh size (mm)")
        XCTAssertEqual(gear.requiredMeasurements[0].apiCode, "ME")
        XCTAssertEqual(gear.requiredMeasurements[0].unit, "mm")
        XCTAssertEqual(gear.variableMeasurements.map(\.id), ["times-shot"])
    }

    // MARK: Vessel-length band filtering

    func test_make_dropsCharacteristics_notApplicableToTheVesselLengthBand() throws {
        let canonical = makeCanonical(applicableCharacteristics: [
            makeCharacteristic(characteristicId: "mesh-size", fixed: true, vesselLengthApplicability: ["10-to-12m"]),
            makeCharacteristic(characteristicId: "times-shot", fixed: false, vesselLengthApplicability: ["under-10m"])
        ])
        let mobile = makeMobile()
        let measurementsById = [
            "mesh-size": makeMeasurementDefinition(id: "mesh-size"),
            "times-shot": makeMeasurementDefinition(id: "times-shot", label: "Times shot")
        ]

        let gear = try GearOption.make(
            canonical: canonical,
            mobile: mobile,
            measurementsById: measurementsById,
            vesselLengthBand: "under-10m"
        )

        XCTAssertTrue(gear.requiredMeasurements.isEmpty, "mesh-size only applies to 10-to-12m, not under-10m")
        XCTAssertEqual(gear.variableMeasurements.map(\.id), ["times-shot"])
    }

    func test_make_honoursAnExplicitVesselLengthBandOverride() throws {
        let canonical = makeCanonical(applicableCharacteristics: [
            makeCharacteristic(characteristicId: "mesh-size", fixed: true, vesselLengthApplicability: ["over-12m"])
        ])
        let mobile = makeMobile()
        let measurementsById = ["mesh-size": makeMeasurementDefinition(id: "mesh-size")]

        let gear = try GearOption.make(
            canonical: canonical,
            mobile: mobile,
            measurementsById: measurementsById,
            vesselLengthBand: "over-12m"
        )

        XCTAssertEqual(gear.requiredMeasurements.map(\.id), ["mesh-size"])
    }

    // MARK: Minimal item (no category, no characteristics)

    func test_make_toleratesMinimalRecords_withNoCategoryOrCharacteristics() throws {
        let canonical = makeCanonical(categoryId: nil, pairFishing: nil, applicableCharacteristics: nil)
        let mobile = makeMobile(category: nil, pairFishing: nil)

        let gear = try GearOption.make(canonical: canonical, mobile: mobile, measurementsById: [:])

        XCTAssertNil(gear.categoryCode)
        XCTAssertNil(gear.categoryName)
        XCTAssertNil(gear.isPairFishing)
        XCTAssertTrue(gear.requiredMeasurements.isEmpty)
        XCTAssertTrue(gear.variableMeasurements.isEmpty)
    }

    // MARK: Unresolved measurement ids — strict, throws rather than dropping

    func test_make_throwsUnresolvedGearMeasurement_whenCharacteristicHasNoMatchingDefinition() {
        let canonical = makeCanonical(applicableCharacteristics: [
            makeCharacteristic(characteristicId: "unknown-id", fixed: true)
        ])
        let mobile = makeMobile()

        XCTAssertThrowsError(
            try GearOption.make(canonical: canonical, mobile: mobile, measurementsById: [:])
        ) { error in
            guard case let ReferenceDataValidationError.unresolvedGearMeasurement(gearCode, measurementId) = error else {
                return XCTFail("Expected .unresolvedGearMeasurement, got \(error)")
            }
            XCTAssertEqual(gearCode, "TBB")
            XCTAssertEqual(measurementId, "unknown-id")
        }
    }

    // MARK: Codable round-trip (new optional fields)

    func test_codable_roundTripsEveryNewField() throws {
        let canonical = makeCanonical(applicableCharacteristics: [makeCharacteristic(characteristicId: "mesh-size", fixed: true)])
        let mobile = makeMobile()
        let gear = try GearOption.make(
            canonical: canonical,
            mobile: mobile,
            measurementsById: ["mesh-size": makeMeasurementDefinition()]
        )

        let data = try JSONEncoder().encode(gear)
        let decoded = try JSONDecoder().decode(GearOption.self, from: data)

        XCTAssertEqual(decoded, gear)
    }

    func test_decode_toleratesPersistedJSON_predatingReferenceDataFields() throws {
        // The exact shape a persisted favourite could hold on disk before this change — no
        // `referenceId`/`categoryCode`/`categoryName`/`isPairFishing` keys at all, matching
        // `PortOptionMappingTests`'s equivalent backward-compatibility test.
        let json = """
        { "id": "SX", "name": "Seine nets (not specified)", "requiredMeasurements": [], "variableMeasurements": [] }
        """
        let decoded = try JSONDecoder().decode(GearOption.self, from: Data(json.utf8))

        XCTAssertEqual(decoded, GearOption(id: "SX", name: "Seine nets (not specified)"))
        XCTAssertNil(decoded.referenceId)
        XCTAssertNil(decoded.categoryCode)
        XCTAssertNil(decoded.categoryName)
        XCTAssertNil(decoded.isPairFishing)
    }

    // MARK: Convenience inits — unaffected by the new fields

    func test_bundledCatalogueInits_leaveNewFieldsNil() {
        let gear = GearOption.seineNets

        XCTAssertNil(gear.referenceId)
        XCTAssertNil(gear.categoryCode)
        XCTAssertNil(gear.categoryName)
        XCTAssertNil(gear.isPairFishing)
    }
}
