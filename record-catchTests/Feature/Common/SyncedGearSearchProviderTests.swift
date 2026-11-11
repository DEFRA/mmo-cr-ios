//
//  SyncedGearSearchProviderTests.swift
//  record-catchTests
//
//  Covers `SyncedGearSearchProvider` against a real, in-memory `ReferenceDataStore` (see
//  ADR-0024 "Consumers").
//

import XCTest
import SwiftData
@testable import record_catch

final class SyncedGearSearchProviderTests: XCTestCase {

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

    private func seed(_ store: ReferenceDataStore, gears: [GearOption]) async throws {
        let encoder = JSONEncoder()
        let items = try gears.map {
            ReferenceDataStore.ItemPayload(itemID: $0.id, sortName: $0.name, payload: try encoder.encode($0))
        }
        try await store.replace(dataset: .gears, items: items, state: makeState())
    }

    func test_allGears_returnsEveryStoredGear() async throws {
        let store = try makeStore()
        try await seed(store, gears: [
            GearOption(id: "TBB", name: "Beam trawl"),
            GearOption(id: "SDN", name: "Danish seine")
        ])
        let sut = SyncedGearSearchProvider(store: store)

        let results = try await sut.allGears()

        XCTAssertEqual(Set(results.map(\.name)), ["Beam trawl", "Danish seine"])
    }

    func test_allGears_returnsEmpty_whenStoreIsNil() async throws {
        let sut = SyncedGearSearchProvider(store: nil)

        let results = try await sut.allGears()

        XCTAssertTrue(results.isEmpty)
    }

    func test_allGears_returnsEmpty_beforeAnySync() async throws {
        let store = try makeStore()
        let sut = SyncedGearSearchProvider(store: store)

        let results = try await sut.allGears()

        XCTAssertTrue(results.isEmpty)
    }
}
