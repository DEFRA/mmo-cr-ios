//
//  SpeciesOptionMappingTests.swift
//  record-catchTests
//
//  Covers SpeciesDTO/SpeciesOption mapping and name derivation for the API's canonical view (see
//  ADR-0018 addendum — the species dataset). Unlike `VesselOptionMappingTests`, species has no
//  backwards-compatibility seam: this is this app's own `Codable` shape going forward, so an
//  encode/decode round trip is also covered here rather than a legacy-payload tolerance test.
//

import XCTest
@testable import record_catch

final class SpeciesOptionMappingTests: XCTestCase {

    private func makeDTO(
        id: String = "1",
        faoCode: String? = "COD",
        scientificName: String? = "Gadus morhua",
        commonNames: [SpeciesNameDTO]? = [SpeciesNameDTO(id: "n1", countryCode: "GBR", name: "Atlantic cod")],
        localNames: [SpeciesNameDTO]? = [],
        active: Bool? = true
    ) -> SpeciesDTO {
        SpeciesDTO(
            id: id,
            faoCode: faoCode,
            scientificName: scientificName,
            commonNames: commonNames,
            localNames: localNames,
            active: active
        )
    }

    // MARK: name derivation

    func test_init_derivesName_asGBRCommonNameAndFAOCode_whenBothPresent() {
        let dto = makeDTO()

        let option = SpeciesOption(dto: dto)

        XCTAssertEqual(option.name, "Atlantic cod (COD)")
    }

    func test_init_prefersGBRCommonName_overOtherCountries() {
        let dto = makeDTO(commonNames: [
            SpeciesNameDTO(id: "n1", countryCode: "FRA", name: "Morue"),
            SpeciesNameDTO(id: "n2", countryCode: "GBR", name: "Atlantic cod")
        ])

        let option = SpeciesOption(dto: dto)

        XCTAssertEqual(option.name, "Atlantic cod (COD)")
    }

    func test_init_fallsBackToFirstCommonName_whenNoGBREntry() {
        let dto = makeDTO(commonNames: [SpeciesNameDTO(id: "n1", countryCode: "FRA", name: "Morue")])

        let option = SpeciesOption(dto: dto)

        XCTAssertEqual(option.name, "Morue (COD)")
    }

    func test_init_fallsBackToScientificName_whenNoCommonNames() {
        let dto = makeDTO(commonNames: [])

        let option = SpeciesOption(dto: dto)

        XCTAssertEqual(option.name, "Gadus morhua (COD)")
    }

    func test_init_fallsBackToId_whenNoCommonNamesOrScientificName() {
        let dto = makeDTO(id: "1", scientificName: nil, commonNames: [])

        let option = SpeciesOption(dto: dto)

        XCTAssertEqual(option.name, "1 (COD)")
    }

    func test_init_omitsFAOCodeSuffix_whenFAOCodeMissing() {
        let dto = makeDTO(faoCode: nil)

        let option = SpeciesOption(dto: dto)

        XCTAssertEqual(option.name, "Atlantic cod")
    }

    // MARK: Full mapping

    func test_init_mapsAllOptionalFields() {
        let dto = SpeciesDTO(
            id: "5E9E48CF-7BCE-4653-ABA9-9F54591CC814",
            faoCode: "QSC",
            scientificName: "Aequipecten opercularis",
            commonNames: [SpeciesNameDTO(id: "n1", countryCode: "GBR", name: "Queen scallop")],
            localNames: [SpeciesNameDTO(id: "n2", countryCode: "GBR", name: "Queenie")],
            active: false
        )

        let option = SpeciesOption(dto: dto)

        XCTAssertEqual(option.id, "5E9E48CF-7BCE-4653-ABA9-9F54591CC814")
        XCTAssertEqual(option.name, "Queen scallop (QSC)")
        XCTAssertEqual(option.faoCode, "QSC")
        XCTAssertEqual(option.scientificName, "Aequipecten opercularis")
        XCTAssertEqual(option.commonNames, [SpeciesName(id: "n1", countryCode: "GBR", name: "Queen scallop")])
        XCTAssertEqual(option.localNames, [SpeciesName(id: "n2", countryCode: "GBR", name: "Queenie")])
        XCTAssertFalse(option.isActive)
    }

    func test_init_toleratesMinimalDTO_withOnlyId() {
        let dto = SpeciesDTO(
            id: "1",
            faoCode: nil,
            scientificName: nil,
            commonNames: nil,
            localNames: nil,
            active: nil
        )

        let option = SpeciesOption(dto: dto)

        XCTAssertEqual(option.id, "1")
        XCTAssertEqual(option.name, "1")
        XCTAssertNil(option.faoCode)
        XCTAssertNil(option.scientificName)
        XCTAssertEqual(option.commonNames, [])
        XCTAssertEqual(option.localNames, [])
        XCTAssertTrue(option.isActive, "Defaults to active when the API omits the field")
    }

    // MARK: withWeights

    func test_withWeights_preservesReferenceDataFields() {
        let option = SpeciesOption(dto: makeDTO())

        let captured = option.withWeights(above: "12.5", below: "1.0", discarded: nil)

        XCTAssertEqual(captured.faoCode, option.faoCode)
        XCTAssertEqual(captured.scientificName, option.scientificName)
        XCTAssertEqual(captured.commonNames, option.commonNames)
        XCTAssertEqual(captured.weightAboveMinimumKg, "12.5")
        XCTAssertEqual(captured.weightBelowMinimumKg, "1.0")
        XCTAssertNil(captured.weightLegallyDiscardedKg)
    }

    // MARK: Codable round trip (no backwards-compatibility seam — see type doc comment)

    func test_codable_roundTripsEveryField() throws {
        let option = SpeciesOption(dto: makeDTO()).withWeights(above: "12.5", below: "1.0", discarded: "0.5")

        let data = try JSONEncoder().encode(option)
        let decoded = try JSONDecoder().decode(SpeciesOption.self, from: data)

        XCTAssertEqual(decoded, option)
    }
}
