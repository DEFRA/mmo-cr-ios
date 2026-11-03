import Foundation
import SwiftData

/// Which kind of favourite a `FavouriteEntity` row stores. One shared entity/table backs all
/// three favourites lists (ports, gears, species) rather than three near-identical `@Model`
/// types, since they only differ in which `Codable` domain type their `payload` decodes to (see
/// ADR-0023).
enum FavouriteKind: String, Codable, Sendable {
    case port
    case gear
    case species
}

/// The on-device, SwiftData-persisted representation of a single favourite (port, gear or
/// species) belonging to the signed-in user — not the in-progress trip (see ADR-0023).
///
/// Favourites are **per-user, not per-trip**: unlike `CatchRecordEntity` (one row per in-progress
/// journey), a `FavouriteEntity` row is created once and then reused across every future trip
/// until the user removes it or signs out. `key` (`"<kind>.<itemID>"`) is the natural unique
/// identity — the same item can never be favourited twice under the same kind.
///
/// Not synced to iCloud — offline-first, device-local source of truth, mirroring
/// `CatchRecordEntity`'s data-at-rest posture (ADR-0014).
@Model
final class FavouriteEntity {
    @Attribute(.unique) var key: String
    var kindRawValue: String
    var itemID: String
    /// JSON-encoded domain value (`PortOption`, `GearOption` or `SpeciesOption`).
    var payload: Data
    var updatedAt: Date

    init(key: String, kindRawValue: String, itemID: String, payload: Data, updatedAt: Date) {
        self.key = key
        self.kindRawValue = kindRawValue
        self.itemID = itemID
        self.payload = payload
        self.updatedAt = updatedAt
    }
}

/// Shared fetch/insert/delete logic over `FavouriteEntity`, used by every
/// `SwiftDataFavourite*Provider` so the three providers don't each re-implement the same
/// predicate/encode/decode plumbing (see ADR-0023). Not a protocol conformance itself — each
/// provider still implements its own `Favourite*Providing` protocol with its own semantics
/// (e.g. ports skip an existing id, gear/species replace it).
///
/// `nonisolated` (not `@MainActor`): `FavouriteGearProviding`/`FavouritePortsProviding`/
/// `FavouriteSpeciesProviding` are `Sendable` protocols (see ADR-0004) with many call sites that
/// construct a default instance as a `nonisolated` function-parameter default value, so their
/// conformers — including the ones that call into this store — must stay `nonisolated` too
/// (mirrors `StubFavouriteGearProvider`'s existing `@unchecked Sendable` escape hatch: every real
/// call happens on the main actor in practice, since `CatchRecordHostView`'s `modelContext` only
/// is ever read there, but the type system cannot prove that for a `ModelContext`-wrapping type).
nonisolated enum FavouriteStore {

    private static func key(kind: FavouriteKind, itemID: String) -> String {
        "\(kind.rawValue).\(itemID)"
    }

    /// Every favourite of `kind`, decoded as `Item`. A row whose payload fails to decode (e.g. a
    /// future format change) is skipped rather than throwing, so one bad row can never break the
    /// whole list.
    static func items<Item: Decodable>(
        kind: FavouriteKind,
        modelContext: ModelContext,
        as type: Item.Type
    ) throws -> [Item] {
        let kindRawValue = kind.rawValue
        let descriptor = FetchDescriptor<FavouriteEntity>(
            predicate: #Predicate { $0.kindRawValue == kindRawValue }
        )
        let entities = try modelContext.fetch(descriptor)
        let decoder = JSONDecoder()
        return entities.compactMap { try? decoder.decode(Item.self, from: $0.payload) }
    }

    /// Whether a favourite with this `kind`/`itemID` already exists.
    static func exists(kind: FavouriteKind, itemID: String, modelContext: ModelContext) throws -> Bool {
        let targetKey = key(kind: kind, itemID: itemID)
        let descriptor = FetchDescriptor<FavouriteEntity>(predicate: #Predicate { $0.key == targetKey })
        return try !modelContext.fetch(descriptor).isEmpty
    }

    /// Inserts or replaces the favourite with this `kind`/`itemID`.
    static func upsert<Item: Encodable>(
        kind: FavouriteKind,
        itemID: String,
        item: Item,
        modelContext: ModelContext
    ) throws {
        let targetKey = key(kind: kind, itemID: itemID)
        let payload = try JSONEncoder().encode(item)
        let descriptor = FetchDescriptor<FavouriteEntity>(predicate: #Predicate { $0.key == targetKey })
        if let existing = try modelContext.fetch(descriptor).first {
            existing.payload = payload
            existing.updatedAt = Date()
        } else {
            modelContext.insert(FavouriteEntity(
                key: targetKey,
                kindRawValue: kind.rawValue,
                itemID: itemID,
                payload: payload,
                updatedAt: Date()
            ))
        }
        try modelContext.save()
    }

    /// Removes the favourite with this `kind`/`itemID`, if any. A no-op if it doesn't exist.
    static func remove(kind: FavouriteKind, itemID: String, modelContext: ModelContext) throws {
        let targetKey = key(kind: kind, itemID: itemID)
        let descriptor = FetchDescriptor<FavouriteEntity>(predicate: #Predicate { $0.key == targetKey })
        guard let existing = try modelContext.fetch(descriptor).first else { return }
        modelContext.delete(existing)
        try modelContext.save()
    }

    /// Removes every favourite of every kind — used on sign-out, since favourites are per-user
    /// data (see `FavouritesClearing`, `SettingsViewModel.confirmSignOut(favouritesClearing:)`,
    /// ADR-0023).
    static func removeAll(modelContext: ModelContext) throws {
        let entities = try modelContext.fetch(FetchDescriptor<FavouriteEntity>())
        for entity in entities {
            modelContext.delete(entity)
        }
        try modelContext.save()
    }
}
