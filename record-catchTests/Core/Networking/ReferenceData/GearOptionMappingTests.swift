//
//  GearOptionMappingTests.swift
//  record-catchTests
//
//  Covers `GearOption.make(dto:measurementsById:)` — the mapping from a `?view=mobile` gears
//  response item (`GearMobileDTO`) into the domain type (see ADR-0018 addendum "gears dataset").
//  End-to-end decoding through `RemoteReferenceDataClient.fetchGears()` is covered in
//  `ReferenceDataClientTests.swift`; this file isolates the mapping function's own edge cases.
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

    private func makeDTO(
        id: String = "1",
        code: String = "TBB",
        name: String = "Beam trawl",
        category: GearCategoryDTO? = GearCategoryDTO(id: "c1", code: "TRAWL_NETS", name: "Trawl nets"),
        pairFishing: Bool? = false,
        requiredMeasurementIds: [String]? = ["mesh-size"],
        variableMeasurementIds: [String]? = nil
    ) -> GearMobileDTO {
        GearMobileDTO(
            id: id,
            code: code,
            name: name,
            category: category,
            pairFishing: pairFishing,
            requiredMeasurementIds: requiredMeasurementIds,
            variableMeasurementIds: variableMeasurementIds
        )
    }

    // MARK: Full mapping

    func test_make_mapsIdToTheAPICode_notTheGUID() {
        let dto = makeDTO(id: "guid-1", code: "TBB")

        let (gear, _) = GearOption.make(dto: dto, measurementsById: [:])

        XCTAssertEqual(gear.id, "TBB", "Favourites are keyed on the FAO gear code, not the API GUID")
        XCTAssertEqual(gear.referenceId, "guid-1")
    }

    func test_make_mapsCategoryAndPairFishing() {
        let dto = makeDTO(
            category: GearCategoryDTO(id: "c1", code: "TRAWL_NETS", name: "Trawl nets"),
            pairFishing: true
        )

        let (gear, _) = GearOption.make(dto: dto, measurementsById: [:])

        XCTAssertEqual(gear.categoryCode, "TRAWL_NETS")
        XCTAssertEqual(gear.categoryName, "Trawl nets")
        XCTAssertEqual(gear.isPairFishing, true)
    }

    func test_make_resolvesMeasurementIds_intoLabelledMeasurements() {
        let dto = makeDTO(requiredMeasurementIds: ["mesh-size"], variableMeasurementIds: ["times-shot"])
        let measurementsById = [
            "mesh-size": makeMeasurementDefinition(id: "mesh-size", code: "ME", label: "Mesh size (mm)", unit: "mm"),
            "times-shot": makeMeasurementDefinition(
                id: "times-shot",
                code: "TS",
                label: "Number of times the gear was shot",
                unit: "count"
            )
        ]

        let (gear, dropped) = GearOption.make(dto: dto, measurementsById: measurementsById)

        XCTAssertTrue(dropped.isEmpty)
        XCTAssertEqual(gear.requiredMeasurements.count, 1)
        XCTAssertEqual(gear.requiredMeasurements[0].id, "mesh-size")
        XCTAssertEqual(gear.requiredMeasurements[0].labelKey, "Mesh size (mm)")
        XCTAssertEqual(gear.requiredMeasurements[0].apiCode, "ME")
        XCTAssertEqual(gear.requiredMeasurements[0].unit, "mm")
        XCTAssertEqual(gear.variableMeasurements.map(\.id), ["times-shot"])
    }

    // MARK: Minimal item (no category, no measurements)

    func test_make_toleratesMinimalDTO_withNoCategoryOrMeasurements() {
        let dto = makeDTO(category: nil, pairFishing: nil, requiredMeasurementIds: nil, variableMeasurementIds: nil)

        let (gear, dropped) = GearOption.make(dto: dto, measurementsById: [:])

        XCTAssertTrue(dropped.isEmpty)
        XCTAssertNil(gear.categoryCode)
        XCTAssertNil(gear.categoryName)
        XCTAssertNil(gear.isPairFishing)
        XCTAssertTrue(gear.requiredMeasurements.isEmpty)
        XCTAssertTrue(gear.variableMeasurements.isEmpty)
    }

    // MARK: Unresolved measurement ids — dropped, never fail the whole gear

    func test_make_dropsUnresolvedRequiredMeasurementId_andReportsIt() {
        let dto = makeDTO(requiredMeasurementIds: ["unknown-id"], variableMeasurementIds: nil)

        let (gear, dropped) = GearOption.make(dto: dto, measurementsById: [:])

        XCTAssertTrue(gear.requiredMeasurements.isEmpty)
        XCTAssertEqual(dropped, ["unknown-id"])
    }

    func test_make_dropsUnresolvedVariableMeasurementId_andReportsIt() {
        let dto = makeDTO(requiredMeasurementIds: nil, variableMeasurementIds: ["unknown-id"])

        let (gear, dropped) = GearOption.make(dto: dto, measurementsById: [:])

        XCTAssertTrue(gear.variableMeasurements.isEmpty)
        XCTAssertEqual(dropped, ["unknown-id"])
    }

    func test_make_resolvesKnownIds_whileDroppingUnknownOnes_inTheSameList() {
        let dto = makeDTO(requiredMeasurementIds: ["mesh-size", "unknown-id"], variableMeasurementIds: nil)
        let measurementsById = ["mesh-size": makeMeasurementDefinition()]

        let (gear, dropped) = GearOption.make(dto: dto, measurementsById: measurementsById)

        XCTAssertEqual(gear.requiredMeasurements.map(\.id), ["mesh-size"])
        XCTAssertEqual(dropped, ["unknown-id"])
    }

    // MARK: Codable round-trip (new optional fields)

    func test_codable_roundTripsEveryNewField() throws {
        let dto = makeDTO()
        let (gear, _) = GearOption.make(
            dto: dto,
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
