//
//  VesselOptionMappingTests.swift
//  record-catchTests
//
//  Covers VesselDTO/VesselOption mapping and displayName derivation for the API's canonical view
//  (see ADR-0018 §2/§5's correction note on why the connector models canonical, not mobile).
//

import XCTest
@testable import record_catch

final class VesselOptionMappingTests: XCTestCase {

    private func makeDTO(
        id: String = "1",
        name: String = "ACHILLES",
        namePln: String? = nil,
        cfr: String? = nil,
        externalMark: String? = nil,
        typeCode: String? = nil,
        registrationCountryCode: String? = nil,
        lengthOverallMetres: Double? = nil,
        status: String? = nil,
        activeFrom: String? = nil,
        activeTo: String? = nil
    ) -> VesselDTO {
        let identifiers: VesselIdentifiersDTO? = (cfr == nil && externalMark == nil)
            ? nil
            : VesselIdentifiersDTO(
                cfr: cfr,
                uvi: nil,
                mmsi: nil,
                ircs: nil,
                externalMark: externalMark,
                registrationNumber: nil
            )
        return VesselDTO(
            id: id,
            name: name,
            namePln: namePln,
            identifiers: identifiers,
            typeCode: typeCode,
            registrationCountryCode: registrationCountryCode,
            lengthOverallMetres: lengthOverallMetres,
            status: status,
            activeFrom: activeFrom,
            activeTo: activeTo
        )
    }

    // MARK: displayName derivation

    func test_init_usesAPINamePln_whenSupplied() {
        let dto = makeDTO(namePln: "ACHILLES PH1234", externalMark: "PH1234")

        let option = VesselOption(dto: dto)

        XCTAssertEqual(option.displayName, "ACHILLES PH1234")
    }

    func test_init_derivesDisplayName_asNameAndExternalMark_whenNamePlnOmitted() {
        let dto = makeDTO(namePln: nil, externalMark: "PH1234")

        let option = VesselOption(dto: dto)

        XCTAssertEqual(option.displayName, "ACHILLES PH1234")
    }

    func test_init_derivesDisplayName_asNameAlone_whenExternalMarkAndNamePlnBothOmitted() {
        let dto = makeDTO(namePln: nil, externalMark: nil)

        let option = VesselOption(dto: dto)

        XCTAssertEqual(option.displayName, "ACHILLES")
    }

    // MARK: Full mapping

    func test_init_mapsAllOptionalFields() {
        let dto = VesselDTO(
            id: "1",
            name: "ACHILLES",
            namePln: "ACHILLES PH1234",
            identifiers: VesselIdentifiersDTO(
                cfr: "GBR000A1234",
                uvi: nil,
                mmsi: "232001234",
                ircs: "MABC7",
                externalMark: "PH1234",
                registrationNumber: "PH1234"
            ),
            typeCode: "FISHING",
            registrationCountryCode: "GBR",
            lengthOverallMetres: 8.74,
            status: "active",
            activeFrom: "2015-03-17",
            activeTo: nil
        )

        let option = VesselOption(dto: dto)

        XCTAssertEqual(option.id, "1")
        XCTAssertEqual(option.name, "ACHILLES")
        XCTAssertEqual(option.cfr, "GBR000A1234")
        XCTAssertNil(option.uvi)
        XCTAssertEqual(option.mmsi, "232001234")
        XCTAssertEqual(option.ircs, "MABC7")
        XCTAssertEqual(option.externalMark, "PH1234")
        XCTAssertEqual(option.registrationNumber, "PH1234")
        XCTAssertEqual(option.typeCode, "FISHING")
        XCTAssertEqual(option.registrationCountryCode, "GBR")
        XCTAssertEqual(option.lengthOverallMetres, 8.74)
        XCTAssertEqual(option.status, "active")
        XCTAssertEqual(option.activeFrom, "2015-03-17")
        XCTAssertNil(option.activeTo)
    }

    func test_init_toleratesMinimalDTO_withOnlyIdAndName() {
        let dto = makeDTO(id: "1", name: "ACHILLES")

        let option = VesselOption(dto: dto)

        XCTAssertEqual(option.id, "1")
        XCTAssertEqual(option.name, "ACHILLES")
        XCTAssertNil(option.cfr)
        XCTAssertNil(option.externalMark)
        XCTAssertNil(option.lengthOverallMetres)
        XCTAssertNil(option.status)
        XCTAssertEqual(option.displayName, "ACHILLES")
    }

    // MARK: Convenience init — hand-built values

    func test_convenienceInit_usesProvidedDisplayName_whenNonEmpty() {
        let option = VesselOption(id: "1", name: "ACHILLES", displayName: "Custom Display")

        XCTAssertEqual(option.displayName, "Custom Display")
    }

    func test_convenienceInit_derivesDisplayName_whenOmitted() {
        let option = VesselOption(id: "1", name: "ACHILLES", externalMark: "PH1234")

        XCTAssertEqual(option.displayName, "ACHILLES PH1234")
    }

    func test_convenienceInit_derivesDisplayName_asNameAlone_whenNoExternalMark() {
        let option = VesselOption(id: "1", name: "ACHILLES")

        XCTAssertEqual(option.displayName, "ACHILLES")
    }
}
