//
//  SyncedVesselSearchProviderTests.swift
//  record-catchTests
//
//  Covers `SyncedVesselSearchProvider` against a real, in-memory `ReferenceDataStore` (see
//  ADR-0024/ADR-0028), mirroring `SyncedPortSearchProviderTests`'s fixture style for the vessel
//  equivalent.
//

import XCTest
import SwiftData
@testable import record_catch

final class SyncedVesselSearchProviderTests: XCTestCase {

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

    private func seed(_ store: ReferenceDataStore, vessels: [VesselOption]) async throws {
        let encoder = JSONEncoder()
        let items = try vessels.map {
            ReferenceDataStore.ItemPayload(itemID: $0.id, sortName: $0.displayName, payload: try encoder.encode($0))
        }
        try await store.replace(dataset: .vessels, items: items, state: makeState())
    }

    func test_vessels_returnsEmpty_whenStoreIsNil() async {
        let sut = SyncedVesselSearchProvider(store: nil)

        let results = await sut.vessels()

        XCTAssertTrue(results.isEmpty)
    }

    func test_vessels_returnsEveryStoredActiveVessel_sortedByDisplayName() async throws {
        let store = try makeStore()
        try await seed(store, vessels: [
            VesselOption(id: "2", name: "SEA SPRAY", displayName: "SEA SPRAY BM45"),
            VesselOption(id: "1", name: "ACHILLES", displayName: "ACHILLES PH1234")
        ])
        let sut = SyncedVesselSearchProvider(store: store)

        let results = await sut.vessels()

        XCTAssertEqual(results.map(\.displayName), ["ACHILLES PH1234", "SEA SPRAY BM45"])
    }

    func test_vessels_treatsVesselWithNoStatusOrActiveTo_asActive() async throws {
        let store = try makeStore()
        try await seed(store, vessels: [VesselOption(id: "1", name: "ACHILLES")])
        let sut = SyncedVesselSearchProvider(store: store)

        let results = await sut.vessels()

        XCTAssertEqual(results.map(\.name), ["ACHILLES"])
    }

    func test_vessels_excludesVessel_whenStatusIsNotActive() async throws {
        let store = try makeStore()
        try await seed(store, vessels: [
            VesselOption(id: "1", name: "ACHILLES", syncMetadata: VesselOption.SyncMetadata(status: "active")),
            VesselOption(id: "2", name: "RETIRED", syncMetadata: VesselOption.SyncMetadata(status: "inactive"))
        ])
        let sut = SyncedVesselSearchProvider(store: store)

        let results = await sut.vessels()

        XCTAssertEqual(results.map(\.name), ["ACHILLES"])
    }

    func test_vessels_treatsStatus_asActive_caseInsensitively() async throws {
        let store = try makeStore()
        try await seed(store, vessels: [
            VesselOption(id: "1", name: "ACHILLES", syncMetadata: VesselOption.SyncMetadata(status: "ACTIVE"))
        ])
        let sut = SyncedVesselSearchProvider(store: store)

        let results = await sut.vessels()

        XCTAssertEqual(results.map(\.name), ["ACHILLES"])
    }

    func test_vessels_excludesVessel_whenActiveToIsInThePast() async throws {
        let store = try makeStore()
        try await seed(store, vessels: [
            VesselOption(id: "1", name: "ACHILLES"),
            VesselOption(id: "2", name: "RETIRED", syncMetadata: VesselOption.SyncMetadata(activeTo: "2000-01-01"))
        ])
        let sut = SyncedVesselSearchProvider(store: store)

        let results = await sut.vessels()

        XCTAssertEqual(results.map(\.name), ["ACHILLES"])
    }

    func test_vessels_includesVessel_whenActiveToIsInTheFuture() async throws {
        let store = try makeStore()
        try await seed(store, vessels: [
            VesselOption(id: "1", name: "ACHILLES", syncMetadata: VesselOption.SyncMetadata(activeTo: "2999-01-01"))
        ])
        let sut = SyncedVesselSearchProvider(store: store)

        let results = await sut.vessels()

        XCTAssertEqual(results.map(\.name), ["ACHILLES"])
    }

    func test_vessels_returnsEmpty_whenNothingSynced() async throws {
        let store = try makeStore()
        let sut = SyncedVesselSearchProvider(store: store)

        let results = await sut.vessels()

        XCTAssertTrue(results.isEmpty)
    }

    func test_vesselNamed_returnsMatch_whenPresent() async throws {
        let store = try makeStore()
        try await seed(store, vessels: [VesselOption(id: "1", name: "ACHILLES")])
        let sut = SyncedVesselSearchProvider(store: store)

        let result = await sut.vessel(named: "ACHILLES")

        XCTAssertEqual(result?.id, "1")
    }

    func test_vesselNamed_returnsNil_whenNoMatch() async throws {
        let store = try makeStore()
        try await seed(store, vessels: [VesselOption(id: "1", name: "ACHILLES")])
        let sut = SyncedVesselSearchProvider(store: store)

        let result = await sut.vessel(named: "UNKNOWN")

        XCTAssertNil(result)
    }
}
