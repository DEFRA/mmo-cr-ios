//
//  SyncedSpeciesSearchProviderTests.swift
//  record-catchTests
//
//  Covers `SyncedSpeciesSearchProvider` against a real, in-memory `ReferenceDataStore` (see
//  ADR-0024 "Consumers").
//

import XCTest
import SwiftData
@testable import record_catch

final class SyncedSpeciesSearchProviderTests: XCTestCase {

    private func makeStore() throws -> ReferenceDataStore {
        let container = try ModelContainer(
            for: ReferenceItemEntity.self, ReferenceDatasetStateEntity.self, ReferenceBlobEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ReferenceDataStore(modelContainer: container)
    }

    private func makeState() -> ReferenceDataStore.StateSnapshot {
        ReferenceDataStore.StateSnapshot(
            collectionId: "c1", version: "v1", schemaVersion: "1.0", itemCount: 1,
            lastModified: "2026-01-01T00:00:00Z", syncedAt: Date(), payloadFormatVersion: 1
        )
    }

    private func seed(_ store: ReferenceDataStore, species: [SpeciesOption]) async throws {
        let encoder = JSONEncoder()
        let items = try species.map {
            ReferenceDataStore.ItemPayload(itemID: $0.id, sortName: $0.name, payload: try encoder.encode($0))
        }
        try await store.replace(dataset: .species, items: items, state: makeState())
    }

    func test_allSpecies_returnsEveryStoredActiveSpecies() async throws {
        let store = try makeStore()
        try await seed(store, species: [
            SpeciesOption(id: "1", name: "Atlantic cod (COD)"),
            SpeciesOption(id: "2", name: "Seabass (BSS)")
        ])
        let sut = SyncedSpeciesSearchProvider(store: store)

        let results = try await sut.allSpecies()

        XCTAssertEqual(Set(results.map(\.name)), ["Atlantic cod (COD)", "Seabass (BSS)"])
    }

    func test_allSpecies_excludesInactiveSpecies() async throws {
        let store = try makeStore()
        let active = SpeciesOption(id: "1", name: "Atlantic cod (COD)")
        let inactive = SpeciesOption(
            id: "2",
            name: "Retired species",
            details: SpeciesOption.ReferenceDetails(isActive: false)
        )
        try await seed(store, species: [active, inactive])
        let sut = SyncedSpeciesSearchProvider(store: store)

        let results = try await sut.allSpecies()

        XCTAssertEqual(results.map(\.name), ["Atlantic cod (COD)"])
    }

    func test_searchSpecies_belowMinimumCharacters_returnsEmpty() async throws {
        let store = try makeStore()
        try await seed(store, species: [SpeciesOption(id: "1", name: "Atlantic cod (COD)")])
        let sut = SyncedSpeciesSearchProvider(minimumCharacters: 2, store: store)

        let results = try await sut.searchSpecies(matching: "a")

        XCTAssertTrue(results.isEmpty)
    }

    func test_searchSpecies_matchesCaseInsensitively() async throws {
        let store = try makeStore()
        try await seed(store, species: [
            SpeciesOption(id: "1", name: "Atlantic cod (COD)"),
            SpeciesOption(id: "2", name: "Seabass (BSS)")
        ])
        let sut = SyncedSpeciesSearchProvider(store: store)

        let results = try await sut.searchSpecies(matching: "COD")

        XCTAssertEqual(results.map(\.name), ["Atlantic cod (COD)"])
    }

    func test_allSpecies_returnsEmpty_whenStoreIsNil() async throws {
        let sut = SyncedSpeciesSearchProvider(store: nil)

        let results = try await sut.allSpecies()

        XCTAssertTrue(results.isEmpty)
    }
}
