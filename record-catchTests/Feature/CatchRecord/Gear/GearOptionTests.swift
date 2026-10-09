//
//  GearOptionTests.swift
//  record-catchTests
//
//  Unit tests for `GearOption`'s domain logic: the fishing-gear reference catalogue (ADR-0012),
//  the `with…Measurements` copy helpers, and the `init(name:)` convenience used throughout the
//  rest of the test suite. Added alongside the SonarCloud PR #40 coverage fix (`GearOption.swift`
//  showed 0% new-code coverage despite being referenced by many other tests).
//

import XCTest
@testable import record_catch

final class GearOptionTests: XCTestCase {

    // MARK: - Catalogue invariants

    func test_all_containsSeineNets() {
        XCTAssertTrue(GearOption.all.contains(.seineNets))
    }

    func test_all_idsAreUnique() {
        let ids = GearOption.all.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count, "Every gear in the catalogue must have a unique id")
    }

    func test_all_namesAreNonEmpty() {
        XCTAssertTrue(GearOption.all.allSatisfy { !$0.name.isEmpty })
    }

    func test_mechanisedDredges_definesNoMeasurements() {
        guard let gear = GearOption.all.first(where: { $0.id == "HMD" }) else {
            return XCTFail("Expected the catalogue to contain Mechanised dredges (HMD)")
        }
        XCTAssertTrue(gear.requiredMeasurements.isEmpty)
        XCTAssertTrue(gear.variableMeasurements.isEmpty)
    }

    func test_miscellaneousGear_definesNoMeasurements() {
        guard let gear = GearOption.all.first(where: { $0.id == "MIS" }) else {
            return XCTFail("Expected the catalogue to contain Miscellaneous gear (diving) (MIS)")
        }
        XCTAssertTrue(gear.requiredMeasurements.isEmpty)
        XCTAssertTrue(gear.variableMeasurements.isEmpty)
    }

    // MARK: - init(name:)

    func test_initName_usesNameAsId() {
        let gear = GearOption(name: "Trawl nets")
        XCTAssertEqual(gear.id, "Trawl nets")
        XCTAssertEqual(gear.name, "Trawl nets")
        XCTAssertTrue(gear.requiredMeasurements.isEmpty)
        XCTAssertTrue(gear.variableMeasurements.isEmpty)
    }

    // MARK: - withRequiredMeasurements / withVariableMeasurements

    func test_withRequiredMeasurements_replacesOnlyRequiredMeasurements() {
        let original = GearOption(name: "Test gear", variableMeasurements: [.timesShot])
        let updated = original.withRequiredMeasurements([.meshSize])

        XCTAssertEqual(updated.id, original.id)
        XCTAssertEqual(updated.name, original.name)
        XCTAssertEqual(updated.requiredMeasurements, [.meshSize])
        XCTAssertEqual(updated.variableMeasurements, original.variableMeasurements)
    }

    func test_withVariableMeasurements_replacesOnlyVariableMeasurements() {
        let original = GearOption(name: "Test gear", requiredMeasurements: [.meshSize])
        let updated = original.withVariableMeasurements([.timesShot])

        XCTAssertEqual(updated.id, original.id)
        XCTAssertEqual(updated.name, original.name)
        XCTAssertEqual(updated.variableMeasurements, [.timesShot])
        XCTAssertEqual(updated.requiredMeasurements, original.requiredMeasurements)
    }

    // MARK: - GearMeasurement.withValue

    func test_measurement_withValue_setsValue_keepsIdAndLabel() {
        let updated = GearMeasurement.meshSize.withValue(80)
        XCTAssertEqual(updated.id, GearMeasurement.meshSize.id)
        XCTAssertEqual(updated.labelKey, GearMeasurement.meshSize.labelKey)
        XCTAssertEqual(updated.value, 80)
    }

    func test_measurement_withValue_nil_clearsValue() {
        let withValue = GearMeasurement.meshSize.withValue(80)
        let cleared = withValue.withValue(nil)
        XCTAssertNil(cleared.value)
    }
}
