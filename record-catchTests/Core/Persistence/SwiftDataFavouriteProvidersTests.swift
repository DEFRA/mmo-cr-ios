import XCTest
import SwiftData
@testable import record_catch

/// Exercises the SwiftData-backed favourites providers (`SwiftDataFavouritePortsProvider`,
/// `SwiftDataFavouriteGearProvider`, `SwiftDataFavouriteSpeciesProvider`) and
/// `SwiftDataFavouritesClearing` against a real, in-memory `ModelContainer` (see ADR-0023),
/// mirroring `SwiftDataCatchRecordDraftStoreTests`. `isStoredInMemoryOnly: true` keeps this
/// hermetic and fast: nothing touches disk.
@MainActor
final class SwiftDataFavouriteProvidersTests: XCTestCase {

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: FavouriteEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    // MARK: - Ports

    func test_ports_addFavourite_thenFetch_returnsIt() async throws {
        let context = try makeContext()
        let sut = SwiftDataFavouritePortsProvider(modelContext: context)

        try await sut.addFavourite(PortOption(name: "Plymouth"))

        let favourites = try await sut.favouritePorts()
        XCTAssertEqual(favourites.map(\.name), ["Plymouth"])
    }

    func test_ports_addFavourite_whenAlreadyPresent_isANoOp() async throws {
        let context = try makeContext()
        let sut = SwiftDataFavouritePortsProvider(modelContext: context)
        try await sut.addFavourite(PortOption(id: "plymouth", name: "Plymouth"))

        // A second add with a different name but the same id must not overwrite (see
        // `FavouritePortsProviding.addFavourite`'s "no-op if already present" contract).
        try await sut.addFavourite(PortOption(id: "plymouth", name: "Changed name"))

        let favourites = try await sut.favouritePorts()
        XCTAssertEqual(favourites.map(\.name), ["Plymouth"])
    }

    func test_ports_favouritePorts_whenEmpty_returnsEmptyArray() async throws {
        let context = try makeContext()
        let sut = SwiftDataFavouritePortsProvider(modelContext: context)

        let favourites = try await sut.favouritePorts()

        XCTAssertTrue(favourites.isEmpty)
    }

    func test_ports_persistAcrossProviderInstances_sharingTheSameModelContext() async throws {
        let context = try makeContext()
        try await SwiftDataFavouritePortsProvider(modelContext: context).addFavourite(PortOption(name: "Hastings"))

        let favourites = try await SwiftDataFavouritePortsProvider(modelContext: context).favouritePorts()

        XCTAssertEqual(favourites.map(\.name), ["Hastings"])
    }

    // MARK: - Gears

    func test_gears_addFavourite_thenFetch_returnsIt() async throws {
        let context = try makeContext()
        let sut = SwiftDataFavouriteGearProvider(modelContext: context)

        try await sut.addFavourite(.seineNets)

        let favourites = try await sut.favouriteGears()
        XCTAssertEqual(favourites.map(\.id), [GearOption.seineNets.id])
    }

    /// Replaces (not duplicates) an existing favourite with the same id — e.g. re-capturing a
    /// gear's required measurements.
    func test_gears_addFavourite_withSameID_replacesExistingEntry() async throws {
        let context = try makeContext()
        let sut = SwiftDataFavouriteGearProvider(modelContext: context)
        try await sut.addFavourite(.seineNets)

        let updated = GearOption.seineNets.withRequiredMeasurements([
            GearMeasurement(id: "meshSize", labelKey: "catchRecord.gear.measurement.meshSize", value: 100)
        ])
        try await sut.addFavourite(updated)

        let favourites = try await sut.favouriteGears()
        XCTAssertEqual(favourites.count, 1)
        XCTAssertEqual(favourites.first?.requiredMeasurements.first?.value, 100)
    }

    // MARK: - Species

    func test_species_addFavourite_thenFetch_returnsIt() async throws {
        let context = try makeContext()
        let sut = SwiftDataFavouriteSpeciesProvider(modelContext: context)

        try await sut.addFavourite(.atlanticCod)

        let favourites = try await sut.favouriteSpecies()
        XCTAssertEqual(favourites.map(\.id), [SpeciesOption.atlanticCod.id])
    }

    func test_species_removeFavourite_removesIt() async throws {
        let context = try makeContext()
        let sut = SwiftDataFavouriteSpeciesProvider(modelContext: context)
        try await sut.addFavourite(.atlanticCod)

        try await sut.removeFavourite(id: SpeciesOption.atlanticCod.id)

        let favourites = try await sut.favouriteSpecies()
        XCTAssertTrue(favourites.isEmpty)
    }

    func test_species_removeFavourite_forUnknownID_isANoOp() async throws {
        let context = try makeContext()
        let sut = SwiftDataFavouriteSpeciesProvider(modelContext: context)

        try await sut.removeFavourite(id: "unknown") // should not throw
    }

    // MARK: - Isolation between kinds (see FavouriteKind, ADR-0023)

    /// A port and a species sharing the same id (unlikely, but not precluded by either domain
    /// type) must not collide — `FavouriteEntity.key` is namespaced by kind.
    func test_differentKinds_withTheSameID_doNotCollide() async throws {
        let context = try makeContext()
        try await SwiftDataFavouritePortsProvider(modelContext: context).addFavourite(PortOption(id: "shared", name: "A port"))
        try await SwiftDataFavouriteSpeciesProvider(modelContext: context).addFavourite(
            SpeciesOption(id: "shared", name: "A species")
        )

        let ports = try await SwiftDataFavouritePortsProvider(modelContext: context).favouritePorts()
        let species = try await SwiftDataFavouriteSpeciesProvider(modelContext: context).favouriteSpecies()

        XCTAssertEqual(ports.map(\.name), ["A port"])
        XCTAssertEqual(species.map(\.name), ["A species"])
    }

    // MARK: - Clearing on sign-out (see FavouritesClearing, ADR-0023)

    func test_favouritesClearing_removesEveryFavourite_ofEveryKind() async throws {
        let context = try makeContext()
        try await SwiftDataFavouritePortsProvider(modelContext: context).addFavourite(PortOption(name: "Plymouth"))
        try await SwiftDataFavouriteGearProvider(modelContext: context).addFavourite(.seineNets)
        try await SwiftDataFavouriteSpeciesProvider(modelContext: context).addFavourite(.atlanticCod)

        try SwiftDataFavouritesClearing(modelContext: context).clearAllFavourites()

        let ports = try await SwiftDataFavouritePortsProvider(modelContext: context).favouritePorts()
        let gears = try await SwiftDataFavouriteGearProvider(modelContext: context).favouriteGears()
        let species = try await SwiftDataFavouriteSpeciesProvider(modelContext: context).favouriteSpecies()
        XCTAssertTrue(ports.isEmpty)
        XCTAssertTrue(gears.isEmpty)
        XCTAssertTrue(species.isEmpty)
    }

    func test_noOpFavouritesClearing_neverThrows_andIsAGenuineNoOp() {
        XCTAssertNoThrow(try NoOpFavouritesClearing().clearAllFavourites())
    }
}
