//
//  PortOptionMappingTests.swift
//  record-catchTests
//
//  Covers PortDTO/PortOption mapping for the reference-data API's `ports` dataset canonical view
//  (see ADR-0018 addendum). `PortOption` predates this connector (ADR-0004) and is already
//  persisted inside `CatchRecordDraft` (ADR-0014), so — unlike `SpeciesOption` — the new
//  `code`/`countryCode`/`isActive` fields are modelled as optional types rather than non-optional
//  with a default, and this file also asserts that previously-persisted JSON lacking those keys
//  still decodes via the synthesized `Codable` conformance.
//

import XCTest
@testable import record_catch

final class PortOptionMappingTests: XCTestCase {

    private func makeDTO(
        id: String = "1",
        name: String = "Aberdeen",
        code: String? = "GBABD",
        countryCode: String? = "GBR",
        coordinate: PortCoordinate? = PortCoordinate(latitude: 57.1430015563965, longitude: -2.0789999961853),
        active: Bool? = true
    ) -> PortDTO {
        PortDTO(id: id, name: name, code: code, countryCode: countryCode, coordinate: coordinate, active: active)
    }

    // MARK: Full mapping

    func test_init_mapsAllOptionalFields() {
        let dto = makeDTO()

        let option = PortOption(dto: dto)

        XCTAssertEqual(option.id, "1")
        XCTAssertEqual(option.name, "Aberdeen")
        XCTAssertEqual(option.code, "GBABD")
        XCTAssertEqual(option.countryCode, "GBR")
        XCTAssertEqual(option.coordinate, PortCoordinate(latitude: 57.1430015563965, longitude: -2.0789999961853))
        XCTAssertEqual(option.isActive, true)
    }

    func test_init_toleratesMinimalDTO_withOnlyIdAndName() {
        let dto = makeDTO(
            code: nil,
            countryCode: nil,
            coordinate: nil,
            active: nil
        )

        let option = PortOption(dto: dto)

        XCTAssertEqual(option.id, "1")
        XCTAssertEqual(option.name, "Aberdeen")
        XCTAssertNil(option.code)
        XCTAssertNil(option.countryCode)
        XCTAssertNil(option.coordinate)
        XCTAssertNil(option.isActive, "nil (not a default true) when the API omits the field — distinct from the stub/bundled sources, which also have nil here")
    }

    func test_init_toleratesNullCoordinate_matchingRealAPIPorts() {
        // A handful of real reference-data ports (e.g. "Fowey") have a null coordinate.
        let dto = makeDTO(coordinate: nil)

        let option = PortOption(dto: dto)

        XCTAssertNil(option.coordinate)
    }

    // MARK: Convenience inits — unaffected by the new fields

    func test_convenienceInit_leavesNewFieldsNil() {
        let option = PortOption(id: "1", name: "Aberdeen")

        XCTAssertNil(option.code)
        XCTAssertNil(option.countryCode)
        XCTAssertNil(option.isActive)
    }

    func test_nameOnlyConvenienceInit_usesNameAsId() {
        let option = PortOption(name: "Aberdeen")

        XCTAssertEqual(option.id, "Aberdeen")
        XCTAssertNil(option.code)
        XCTAssertNil(option.countryCode)
        XCTAssertNil(option.isActive)
    }

    // MARK: Backward-compatible Codable — persisted drafts predating these fields

    func test_decode_toleratesPersistedJSON_predatingReferenceDataFields() throws {
        // The exact shape `CatchRecordDraftStore` could hold on disk before this change — no
        // `code`/`countryCode`/`isActive` keys at all.
        let json = """
        { "id": "Aberdeen", "name": "Aberdeen", "coordinate": null }
        """
        let decoded = try JSONDecoder().decode(PortOption.self, from: Data(json.utf8))

        XCTAssertEqual(decoded, PortOption(name: "Aberdeen"))
        XCTAssertNil(decoded.code)
        XCTAssertNil(decoded.countryCode)
        XCTAssertNil(decoded.isActive)
    }

    func test_codable_roundTripsEveryField() throws {
        let option = PortOption(dto: makeDTO())

        let data = try JSONEncoder().encode(option)
        let decoded = try JSONDecoder().decode(PortOption.self, from: data)

        XCTAssertEqual(decoded, option)
    }
}
