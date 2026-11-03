import Foundation
import SwiftData

/// SwiftData-backed `FavouritePortsProviding` — see ADR-0023. Favourites belong to the signed-in
/// user, not the in-progress trip: they are read/written against the shared, on-device
/// `FavouriteEntity` store, so they persist across app relaunches and every future trip, not just
/// the journey that added them.
///
/// `nonisolated`/`@unchecked Sendable` (mirroring `StubFavouritePortsProvider`): the protocol is
/// `Sendable` with `nonisolated` default-argument call sites throughout the journey's view models,
/// so this conformer must stay constructible/callable from a nonisolated context too. **Every
/// method body explicitly hops onto `MainActor.run` before touching `modelContext`**: a
/// `nonisolated async` method called via `await` from a `@MainActor` view model is **not**
/// guaranteed to execute on the main actor (it can run on the cooperative thread pool) — and
/// `ModelContext` is documented as usable from only one, fixed thread/queue. Without the explicit
/// hop, a write from one screen's view model and a read from the next screen's could race onto
/// different threads and the reader would see a stale fetch (the exact bug this fixes — see
/// `CatchRecordUITests.test_portJourney_addFirstPort_thenSelectDepartureAndReturn_reachesGearSubJourney`).
nonisolated struct SwiftDataFavouritePortsProvider: FavouritePortsProviding, @unchecked Sendable {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func favouritePorts() async throws -> [PortOption] {
        try await MainActor.run {
            let ports = try FavouriteStore.items(kind: .port, modelContext: modelContext, as: PortOption.self)
            return ports.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }

    /// No-op if `port` is already a favourite (mirrors `StubFavouritePortsProvider`).
    func addFavourite(_ port: PortOption) async throws {
        try await MainActor.run {
            guard try !FavouriteStore.exists(kind: .port, itemID: port.id, modelContext: modelContext) else { return }
            try FavouriteStore.upsert(kind: .port, itemID: port.id, item: port, modelContext: modelContext)
        }
    }
}

/// SwiftData-backed `FavouriteGearProviding` — see ADR-0023. As with ports, gears persist per-user
/// across trips rather than only within the journey that added them. See
/// `SwiftDataFavouritePortsProvider`'s doc comment for why this is `nonisolated`/`@unchecked
/// Sendable` and why every method body hops onto `MainActor.run`.
nonisolated struct SwiftDataFavouriteGearProvider: FavouriteGearProviding, @unchecked Sendable {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func favouriteGears() async throws -> [GearOption] {
        try await MainActor.run {
            let gears = try FavouriteStore.items(kind: .gear, modelContext: modelContext, as: GearOption.self)
            return gears.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }

    /// Replaces any existing favourite with the same id (mirrors `StubFavouriteGearProvider`).
    func addFavourite(_ gear: GearOption) async throws {
        try await MainActor.run {
            try FavouriteStore.upsert(kind: .gear, itemID: gear.id, item: gear, modelContext: modelContext)
        }
    }
}

/// SwiftData-backed `FavouriteSpeciesProviding` — see ADR-0023. As with ports/gears, species
/// persist per-user across trips. Only the species itself is persisted here — **not** its
/// per-trip weights, which belong on `CatchRecordDraft.gearCatches[…].speciesCaught` instead (see
/// `RecordSpeciesWeightsViewModel.submit()`), so a weight recorded on one trip never silently
/// carries over to the next. See `SwiftDataFavouritePortsProvider`'s doc comment for why this is
/// `nonisolated`/`@unchecked Sendable` and why every method body hops onto `MainActor.run`.
nonisolated struct SwiftDataFavouriteSpeciesProvider: FavouriteSpeciesProviding, @unchecked Sendable {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func favouriteSpecies() async throws -> [SpeciesOption] {
        try await MainActor.run {
            let species = try FavouriteStore.items(kind: .species, modelContext: modelContext, as: SpeciesOption.self)
            return species.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }

    /// Replaces any existing favourite with the same id (mirrors `StubFavouriteSpeciesProvider`).
    func addFavourite(_ species: SpeciesOption) async throws {
        try await MainActor.run {
            try FavouriteStore.upsert(kind: .species, itemID: species.id, item: species, modelContext: modelContext)
        }
    }

    func removeFavourite(id: String) async throws {
        try await MainActor.run {
            try FavouriteStore.remove(kind: .species, itemID: id, modelContext: modelContext)
        }
    }
}

/// Clears every on-device favourite (ports, gears and species) — used on sign-out, since
/// favourites belong to the signed-in user, not the device (see ADR-0023,
/// `SettingsViewModel.confirmSignOut(favouritesClearing:)`). `@MainActor` (not
/// `Sendable`-constrained like the three providers above), mirroring `CatchRecordDraftStoring`:
/// its only caller, `SettingsViewModel`, is itself `@MainActor`, and `clearAllFavourites()` is
/// synchronous (not `async`), so there is no nonisolated-hop hazard to guard against here.
@MainActor
protocol FavouritesClearing {
    func clearAllFavourites() throws
}

/// SwiftData-backed `FavouritesClearing`.
@MainActor
struct SwiftDataFavouritesClearing: FavouritesClearing {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func clearAllFavourites() throws {
        try FavouriteStore.removeAll(modelContext: modelContext)
    }
}

/// No-op fake for previews/tests that don't care about sign-out clearing favourites.
@MainActor
struct NoOpFavouritesClearing: FavouritesClearing {
    func clearAllFavourites() throws {}
}
