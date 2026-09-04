import XCTest
@testable import record_catch

/// Guards the full fishing-gear reference catalogue seeded into `GearOption.all` (see ADR-0012):
/// its size, unique ids (a real data-quality issue in the source list — the duplicate `PS1` code
/// was resolved by removing the "One boat operated purse seine" row and renaming "Purse seine" to
/// `PS`), and that a couple of representative gears carry the expected measurement definitions.
final class GearOptionCatalogueTests: XCTestCase {

    func test_all_hasExpectedCount() {
        // 36 gears: the source reference list, minus `NK` (gear not known), the duplicate `PS1`
        // ("One boat operated purse seine") and `RG` (recreational gear).
        XCTAssertEqual(GearOption.all.count, 36)
    }

    func test_all_idsAreUnique() {
        let ids = GearOption.all.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count, "GearOption.all contains a duplicate id: \(ids)")
    }

    func test_all_doesNotContainRemovedGears() {
        let ids = Set(GearOption.all.map(\.id))
        XCTAssertFalse(ids.contains("NK"), "Gear not known/not specified must be removed")
        XCTAssertFalse(ids.contains("RG"), "Recreational gear must be removed")
        XCTAssertEqual(
            GearOption.all.filter { $0.id == "PS1" }.count,
            0,
            "The duplicate PS1 code must not appear (renamed to PS)"
        )
    }

    func test_all_containsRenamedPurseSeine() {
        let purseSeine = GearOption.all.first { $0.id == "PS" }
        XCTAssertEqual(purseSeine?.name, "Purse seine")
        XCTAssertEqual(purseSeine?.requiredMeasurements, [.meshSize])
        XCTAssertEqual(purseSeine?.variableMeasurements, [.timesShot])
    }

    func test_beamTrawl_hasTwoRequiredMeasurements_andTimesShotVariable() {
        let beamTrawl = GearOption.all.first { $0.id == "TBB" }
        XCTAssertEqual(beamTrawl?.requiredMeasurements, [.meshSize, .numberOfBeams])
        XCTAssertEqual(beamTrawl?.variableMeasurements, [.timesShot])
    }

    func test_pots_hasNoRequiredMeasurements_andTwoVariableMeasurements() {
        let pots = GearOption.all.first { $0.id == "FPO" }
        XCTAssertEqual(pots?.requiredMeasurements, [])
        XCTAssertEqual(pots?.variableMeasurements, [.potsHauled, .potsLeft])
    }

    func test_gearsWithNoMeasurementsAtAll_defineNeitherList() {
        // Confirmed with the user: zero-measurement gears (HMD, MIS) are followed as-is rather than
        // given synthetic measurements — see `AddGearViewModel.submit()`, which skips the now-empty
        // measurements screen for such a gear.
        for id in ["HMD", "MIS"] {
            let gear = GearOption.all.first { $0.id == id }
            XCTAssertEqual(gear?.requiredMeasurements, [], "\(id) should have no required measurements")
            XCTAssertEqual(gear?.variableMeasurements, [], "\(id) should have no variable measurements")
        }
    }

    func test_seineNets_isIncludedInCatalogue_withCodeSX() {
        XCTAssertTrue(GearOption.all.contains(GearOption.seineNets))
        XCTAssertEqual(GearOption.seineNets.id, "SX")
    }
}
