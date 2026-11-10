//
//  SyncedSpeciesSearchProvider.swift
//  record-catch
//
//  Species search backed by the on-device reference-data sync pipeline (see ADR-0024
//  "Consumers"), replacing the hard-coded `StubSpeciesSearchProvider` fixture in production.
//  Mirrors `StubSpeciesSearchProvider` exactly (same minimum-characters rule, same pure
//  `filtered(...)` helper) so `AddSpeciesViewModel`/`AddSpeciesView` need no changes beyond which
//  provider is injected.
//

import Foundation

/// Reads every synced `SpeciesOption` from `ReferenceDataStore`. Inactive species
/// (`isActive == false`) are excluded, mirroring a server that has retired a species code but not
/// yet removed its historical record.
nonisolated struct SyncedSpeciesSearchProvider: SpeciesSearchProviding {

    let minimumCharacters: Int
    private let store: ReferenceDataStore?

    init(minimumCharacters: Int = 2, store: ReferenceDataStore? = ReferenceDataStoreProvider.shared) {
        self.minimumCharacters = minimumCharacters
        self.store = store
    }

    func searchSpecies(matching query: String) async throws -> [SpeciesOption] {
        StubSpeciesSearchProvider.filtered(
            query: query,
            minimumCharacters: minimumCharacters,
            species: try await loadSpecies()
        )
    }

    func allSpecies() async throws -> [SpeciesOption] {
        try await loadSpecies()
    }

    private func loadSpecies() async throws -> [SpeciesOption] {
        guard let store else { return [] }
        let species = try await store.decodedItems(for: .species, as: SpeciesOption.self)
        return species.filter(\.isActive)
    }
}
