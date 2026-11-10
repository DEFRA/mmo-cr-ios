//
//  SyncedGearSearchProvider.swift
//  record-catch
//
//  Gear search backed by the on-device reference-data sync pipeline (see ADR-0024 "Consumers"),
//  replacing the hard-coded `StubGearSearchProvider` (`GearOption.all`, ADR-0012) catalogue in
//  production. `GearOption` carries no `isActive` field (unlike ports/species), so every synced
//  gear is returned as-is.
//

import Foundation

/// Reads every synced `GearOption` from `ReferenceDataStore`.
nonisolated struct SyncedGearSearchProvider: GearSearchProviding {

    private let store: ReferenceDataStore?

    init(store: ReferenceDataStore? = ReferenceDataStoreProvider.shared) {
        self.store = store
    }

    func allGears() async throws -> [GearOption] {
        guard let store else { return [] }
        return try await store.decodedItems(for: .gears, as: GearOption.self)
    }
}
