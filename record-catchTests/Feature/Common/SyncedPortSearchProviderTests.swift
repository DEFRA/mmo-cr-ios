//
//  SyncedPortSearchProviderTests.swift
//  record-catchTests
//
//  Covers `SyncedPortSearchProvider` against a real, in-memory `ReferenceDataStore` (see
//  ADR-0024 "Consumers"), mirroring `PortSearchProviderTests`'s fixture style for the bundled
//  provider it replaces in production.
//

import XCTest
import SwiftData
@testable import record_catch

final class SyncedPortSearchProviderTests: XCTestCase {

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

    private func seed(_ store: ReferenceDataStore, ports: [PortOption]) async throws {
        let encoder = JSONEncoder()
        let items = try ports.map {
            ReferenceDataStore.ItemPayload(itemID: $0.id, sortName: $0.name, payload: try encoder.encode($0))
        }
        try await store.replace(dataset: .ports, items: items, state: makeState())
    }

    func test_allPorts_returnsEveryStoredActivePort() async throws {
        let store = try makeStore()
        try await seed(store, ports: [PortOption(id: "1", name: "Hull"), PortOption(id: "2", name: "Newlyn")])
        let sut = SyncedPortSearchProvider(store: store)

        let results = try await sut.allPorts()

        XCTAssertEqual(Set(results.map(\.name)), ["Hull", "Newlyn"])
    }

    func test_allPorts_excludesInactivePorts() async throws {
        let store = try makeStore()
        try await seed(store, ports: [
            PortOption(id: "1", name: "Hull", isActive: true),
            PortOption(id: "2", name: "Retired Port", isActive: false)
        ])
        let sut = SyncedPortSearchProvider(store: store)

        let results = try await sut.allPorts()

        XCTAssertEqual(results.map(\.name), ["Hull"])
    }

    func test_searchPorts_belowMinimumCharacters_returnsEmpty() async throws {
        let store = try makeStore()
        try await seed(store, ports: [PortOption(id: "1", name: "Aberdeen")])
        let sut = SyncedPortSearchProvider(minimumCharacters: 2, store: store)

        let results = try await sut.searchPorts(matching: "a")

        XCTAssertTrue(results.isEmpty)
    }

    func test_searchPorts_matchesCaseInsensitively() async throws {
        let store = try makeStore()
        try await seed(store, ports: [PortOption(id: "1", name: "Aberdeen"), PortOption(id: "2", name: "Hull")])
        let sut = SyncedPortSearchProvider(store: store)

        let results = try await sut.searchPorts(matching: "ABER")

        XCTAssertEqual(results.map(\.name), ["Aberdeen"])
    }

    func test_allPorts_returnsEmpty_whenStoreIsNil() async throws {
        let sut = SyncedPortSearchProvider(store: nil)

        let results = try await sut.allPorts()

        XCTAssertTrue(results.isEmpty)
    }
}
