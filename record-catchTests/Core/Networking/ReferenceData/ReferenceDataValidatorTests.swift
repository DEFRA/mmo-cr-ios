//
//  ReferenceDataValidatorTests.swift
//  record-catchTests
//
//  Covers `ReferenceDataValidator`'s pure validation rules (see ADR-0024 "Validation") — every
//  rule is side-effect-free, so these are plain input/output assertions with no fakes needed.
//

import XCTest
@testable import record_catch

final class ReferenceDataValidatorTests: XCTestCase {

    // MARK: validateItemCount

    func test_validateItemCount_throwsEmptyDataset_whenCountIsZero() {
        XCTAssertThrowsError(try ReferenceDataValidator.validateItemCount(dataset: "ports", itemCount: 0, manifestEntry: nil)) {
            XCTAssertEqual($0 as? ReferenceDataValidationError, .emptyDataset(dataset: "ports"))
        }
    }

    func test_validateItemCount_succeeds_whenNoManifestEntrySupplied() throws {
        try ReferenceDataValidator.validateItemCount(dataset: "ports", itemCount: 5, manifestEntry: nil)
    }

    func test_validateItemCount_succeeds_whenCountMatchesManifest() throws {
        let entry = makeManifestEntry(itemCount: 5)
        try ReferenceDataValidator.validateItemCount(dataset: "ports", itemCount: 5, manifestEntry: entry)
    }

    func test_validateItemCount_throwsMismatch_whenCountDiffersFromManifest() {
        let entry = makeManifestEntry(itemCount: 5)
        XCTAssertThrowsError(try ReferenceDataValidator.validateItemCount(dataset: "ports", itemCount: 3, manifestEntry: entry)) {
            XCTAssertEqual($0 as? ReferenceDataValidationError, .itemCountMismatch(dataset: "ports", expected: 5, actual: 3))
        }
    }

    // MARK: validateUniqueIdentifiers

    func test_validateUniqueIdentifiers_succeeds_forDistinctIds() throws {
        try ReferenceDataValidator.validateUniqueIdentifiers(dataset: "ports", identifiers: ["1", "2", "3"])
    }

    func test_validateUniqueIdentifiers_throwsDuplicateIdentifier() {
        XCTAssertThrowsError(try ReferenceDataValidator.validateUniqueIdentifiers(dataset: "ports", identifiers: ["1", "2", "1"])) {
            XCTAssertEqual($0 as? ReferenceDataValidationError, .duplicateIdentifier(dataset: "ports", identifier: "1"))
        }
    }

    // MARK: validatePorts

    func test_validatePorts_succeeds_forWellFormedPorts() throws {
        try ReferenceDataValidator.validatePorts([
            PortOption(id: "1", name: "Aberdeen", coordinate: .init(latitude: 57.1, longitude: -2.1))
        ])
    }

    func test_validatePorts_throwsInvalidItem_forBlankId() {
        let port = PortOption(id: "  ", name: "Aberdeen")
        XCTAssertThrowsError(try ReferenceDataValidator.validatePorts([port])) {
            XCTAssertEqual($0 as? ReferenceDataValidationError, .invalidItem(dataset: "ports", identifier: "  ", reason: "blank id"))
        }
    }

    func test_validatePorts_throwsInvalidItem_forBlankName() {
        let port = PortOption(id: "1", name: "  ")
        XCTAssertThrowsError(try ReferenceDataValidator.validatePorts([port])) {
            XCTAssertEqual($0 as? ReferenceDataValidationError, .invalidItem(dataset: "ports", identifier: "1", reason: "blank name"))
        }
    }

    func test_validatePorts_throwsInvalidItem_forOutOfRangeCoordinate() {
        let port = PortOption(id: "1", name: "Aberdeen", coordinate: .init(latitude: 200, longitude: -2.1))
        XCTAssertThrowsError(try ReferenceDataValidator.validatePorts([port])) {
            XCTAssertEqual(
                $0 as? ReferenceDataValidationError,
                .invalidItem(dataset: "ports", identifier: "1", reason: "coordinate out of range")
            )
        }
    }

    func test_validatePorts_throwsDuplicateIdentifier() {
        let ports = [PortOption(id: "1", name: "Aberdeen"), PortOption(id: "1", name: "Plymouth")]
        XCTAssertThrowsError(try ReferenceDataValidator.validatePorts(ports)) {
            XCTAssertEqual($0 as? ReferenceDataValidationError, .duplicateIdentifier(dataset: "ports", identifier: "1"))
        }
    }

    // MARK: validateSpecies

    func test_validateSpecies_succeeds_forWellFormedSpecies() throws {
        try ReferenceDataValidator.validateSpecies([SpeciesOption(id: "1", name: "Atlantic cod (COD)")])
    }

    func test_validateSpecies_throwsInvalidItem_forBlankName() {
        let species = SpeciesOption(id: "1", name: " ")
        XCTAssertThrowsError(try ReferenceDataValidator.validateSpecies([species])) {
            XCTAssertEqual($0 as? ReferenceDataValidationError, .invalidItem(dataset: "species", identifier: "1", reason: "blank name"))
        }
    }

    func test_validateSpecies_throwsInvalidItem_forBlankId() {
        let species = SpeciesOption(id: " ", name: "Cod")
        XCTAssertThrowsError(try ReferenceDataValidator.validateSpecies([species])) {
            XCTAssertEqual($0 as? ReferenceDataValidationError, .invalidItem(dataset: "species", identifier: " ", reason: "blank id"))
        }
    }

    // MARK: validateVessels

    func test_validateVessels_succeeds_forWellFormedVessels() throws {
        try ReferenceDataValidator.validateVessels([makeVessel(id: "1", name: "ACHILLES", lengthOverallMetres: 9.5)])
    }

    func test_validateVessels_succeeds_whenLengthIsNil() throws {
        try ReferenceDataValidator.validateVessels([VesselOption(id: "1", name: "ACHILLES")])
    }

    func test_validateVessels_throwsInvalidItem_forNonPositiveLength() {
        let vessel = makeVessel(id: "1", name: "ACHILLES", lengthOverallMetres: 0)
        XCTAssertThrowsError(try ReferenceDataValidator.validateVessels([vessel])) {
            XCTAssertEqual(
                $0 as? ReferenceDataValidationError,
                .invalidItem(dataset: "vessels", identifier: "1", reason: "non-positive lengthOverallMetres")
            )
        }
    }

    func test_validateVessels_throwsInvalidItem_forBlankName() {
        let vessel = VesselOption(id: "1", name: "")
        XCTAssertThrowsError(try ReferenceDataValidator.validateVessels([vessel])) {
            XCTAssertEqual($0 as? ReferenceDataValidationError, .invalidItem(dataset: "vessels", identifier: "1", reason: "blank name"))
        }
    }

    // MARK: validateGears

    func test_validateGears_succeeds_forWellFormedGears() throws {
        try ReferenceDataValidator.validateGears([GearOption.seineNets])
    }

    func test_validateGears_throwsInvalidItem_forBlankMeasurementLabel() {
        let measurement = GearMeasurement(id: "m1", labelKey: "  ")
        let gear = GearOption(id: "TBB", name: "Beam trawl", requiredMeasurements: [measurement])
        XCTAssertThrowsError(try ReferenceDataValidator.validateGears([gear])) {
            XCTAssertEqual(
                $0 as? ReferenceDataValidationError,
                .invalidItem(dataset: "gears", identifier: "TBB", reason: "blank measurement label")
            )
        }
    }

    func test_validateGears_throwsDuplicateIdentifier() {
        let gears = [GearOption(id: "TBB", name: "Beam trawl"), GearOption(id: "TBB", name: "Duplicate")]
        XCTAssertThrowsError(try ReferenceDataValidator.validateGears(gears)) {
            XCTAssertEqual($0 as? ReferenceDataValidationError, .duplicateIdentifier(dataset: "gears", identifier: "TBB"))
        }
    }

    // MARK: validateResponseSize

    func test_validateResponseSize_succeeds_withinCap() throws {
        try ReferenceDataValidator.validateResponseSize(dataset: "ports", sizeBytes: 1024)
    }

    func test_validateResponseSize_throwsResponseTooLarge_overCap() {
        let oversized = ReferenceDataValidator.maximumResponseSizeBytes + 1
        XCTAssertThrowsError(try ReferenceDataValidator.validateResponseSize(dataset: "ports", sizeBytes: oversized)) {
            XCTAssertEqual($0 as? ReferenceDataValidationError, .responseTooLarge(dataset: "ports", sizeBytes: oversized))
        }
    }

    // MARK: Test helpers

    private func makeManifestEntry(itemCount: Int?) -> ReferenceDataManifestEntry {
        ReferenceDataManifestEntry(
            dataset: "ports",
            collectionId: "00000000-0000-4000-8000-000000000001",
            version: "v1",
            schemaVersion: "1.0",
            format: "json",
            itemCount: itemCount,
            lastModified: "2026-01-01T00:00:00Z",
            url: "/api/v1/reference-data/ports"
        )
    }

    /// `VesselOption`'s hand-built convenience init doesn't expose `lengthOverallMetres` (only
    /// `init(dto:)` does — see `VesselOption.swift`), so this goes via a minimal `VesselDTO`.
    private func makeVessel(id: String, name: String, lengthOverallMetres: Double?) -> VesselOption {
        VesselOption(dto: VesselDTO(
            id: id,
            name: name,
            namePln: nil,
            identifiers: nil,
            typeCode: nil,
            registrationCountryCode: nil,
            lengthOverallMetres: lengthOverallMetres,
            status: nil,
            activeFrom: nil,
            activeTo: nil
        ))
    }
}
