//
//  ReferenceDataSyncServiceTests.swift
//  record-catchTests
//
//  Covers `ReferenceDataSyncService.sync()` — manifest-driven change detection, per-dataset
//  validation/persistence, and independent per-dataset failure (see ADR-0024 "Manifest-driven
//  change detection"/"Validation"). Uses a real in-memory `ReferenceDataStore` (SwiftData) and a
//  bespoke fake `ReferenceDataFetching` double configurable per method/dataset — `StubReferenceDataClient`
//  only supports one shared error for every call, which can't express "gears failed, everything
//  else succeeded".
//

import XCTest
import SwiftData
@testable import record_catch

/// Per-method configurable `ReferenceDataFetching` double — see file header for why
/// `StubReferenceDataClient` isn't reused here.
private final class FakeReferenceDataFetching: ReferenceDataFetching, @unchecked Sendable {
    var vesselsResult: Result<[VesselOption], Error> = .success([])
    var speciesResult: Result<[SpeciesOption], Error> = .success([])
    var portsResult: Result<[PortOption], Error> = .success([])
    var gearsResult: Result<[GearOption], Error> = .success([])
    var manifestResult: Result<ReferenceDataManifest, Error> = .failure(APIError.response(status: 503, details: nil))

    func fetchVessels() async throws -> [VesselOption] { try vesselsResult.get() }
    func fetchVessel(id _: String) async throws -> VesselOption { throw APIError.response(status: 404, details: nil) }
    func fetchSpecies() async throws -> [SpeciesOption] { try speciesResult.get() }
    func fetchSpecies(id _: String) async throws -> SpeciesOption { throw APIError.response(status: 404, details: nil) }
    func fetchPorts() async throws -> [PortOption] { try portsResult.get() }
    func fetchPort(id _: String) async throws -> PortOption { throw APIError.response(status: 404, details: nil) }
    func fetchGears() async throws -> [GearOption] { try gearsResult.get() }
    func fetchManifest() async throws -> ReferenceDataManifest { try manifestResult.get() }
    func checkHealth() async throws {}
}

final class ReferenceDataSyncServiceTests: XCTestCase {

    private func makeStore() throws -> ReferenceDataStore {
        let container = try ModelContainer(
            for: ReferenceItemEntity.self, ReferenceDatasetStateEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ReferenceDataStore(modelContainer: container)
    }

    private func makeManifest(datasets: [ReferenceDataManifestEntry]) -> ReferenceDataManifest {
        ReferenceDataManifest(manifestId: "00000000-0000-4000-8000-000000000001", version: "2026-01-01T00:00:00Z", datasets: datasets)
    }

    private func makeEntry(
        dataset: String,
        collectionId: String = "c1",
        version: String = "v1",
        schemaVersion: String = "1.0",
        itemCount: Int? = 1
    ) -> ReferenceDataManifestEntry {
        ReferenceDataManifestEntry(
            dataset: dataset,
            collectionId: collectionId,
            version: version,
            schemaVersion: schemaVersion,
            format: "json",
            itemCount: itemCount,
            lastModified: "2026-01-01T00:00:00Z",
            url: "/api/v1/reference-data/\(dataset)"
        )
    }

    /// A manifest covering every dataset `ReferenceDataSyncService` tracks, all pointing at the
    /// same `itemCount: 1` — paired with each fake fetch method returning exactly one item.
    private func makeFullManifest() -> ReferenceDataManifest {
        makeManifest(datasets: ReferenceDataKind.allCases.map { makeEntry(dataset: $0.rawValue) })
    }

    // MARK: First-ever sync — everything fetched and persisted

    func test_sync_firstEverSync_fetchesAndPersistsEveryDataset_reportsUpdated() async throws {
        let store = try makeStore()
        let client = FakeReferenceDataFetching()
        client.manifestResult = .success(makeFullManifest())
        client.portsResult = .success([PortOption(id: "1", name: "Aberdeen")])
        client.speciesResult = .success([SpeciesOption(id: "1", name: "Cod")])
        client.vesselsResult = .success([VesselOption(id: "1", name: "ACHILLES")])
        client.gearsResult = .success([GearOption(id: "TBB", name: "Beam trawl")])
        let sut = ReferenceDataSyncService(client: client, store: store)

        let report = await sut.sync()

        XCTAssertEqual(report.results, [
            "ports": .updated, "species": .updated, "vessels": .updated, "gears": .updated
        ])
        XCTAssertTrue(report.isFullSuccess)
        XCTAssertFalse(report.hasFailure)
        let persisted = try await store.items(for: .ports)
        XCTAssertEqual(persisted.count, 1)
    }

    func test_sync_hasAnyData_isTrue_afterASuccessfulSync() async throws {
        let store = try makeStore()
        let client = FakeReferenceDataFetching()
        client.manifestResult = .success(makeFullManifest())
        client.portsResult = .success([PortOption(id: "1", name: "Aberdeen")])
        client.speciesResult = .success([SpeciesOption(id: "1", name: "Cod")])
        client.vesselsResult = .success([VesselOption(id: "1", name: "ACHILLES")])
        client.gearsResult = .success([GearOption(id: "TBB", name: "Beam trawl")])
        let sut = ReferenceDataSyncService(client: client, store: store)

        _ = await sut.sync()

        let hasAnyData = await sut.hasAnyData()
        XCTAssertTrue(hasAnyData)
    }

    // MARK: Unchanged — matching manifest skips the fetch entirely

    func test_sync_whenManifestMatchesExistingState_reportsUnchanged_withoutRefetching() async throws {
        let store = try makeStore()
        try await store.replace(
            dataset: .ports,
            items: [ReferenceDataStore.ItemPayload(itemID: "1", sortName: "Aberdeen", payload: Data())],
            state: ReferenceDataStore.StateSnapshot(
                collectionId: "c1", version: "v1", schemaVersion: "1.0", itemCount: 1,
                lastModified: "2026-01-01T00:00:00Z", syncedAt: Date(),
                payloadFormatVersion: ReferenceDataSyncService.payloadFormatVersion
            )
        )
        let client = FakeReferenceDataFetching()
        client.manifestResult = .success(makeManifest(datasets: [makeEntry(dataset: "ports", itemCount: 1)]))
        // Deliberately never configured — if the service refetches, it would see this failure.
        client.portsResult = .failure(APIError.response(status: 500, details: nil))
        let sut = ReferenceDataSyncService(client: client, store: store)

        let report = await sut.sync()

        XCTAssertEqual(report.results["ports"], .unchanged)
    }

    func test_sync_refetches_whenManifestVersionHasMoved() async throws {
        let store = try makeStore()
        try await store.replace(
            dataset: .ports,
            items: [ReferenceDataStore.ItemPayload(itemID: "1", sortName: "Aberdeen", payload: Data())],
            state: ReferenceDataStore.StateSnapshot(
                collectionId: "c1", version: "v1", schemaVersion: "1.0", itemCount: 1,
                lastModified: "2026-01-01T00:00:00Z", syncedAt: Date(),
                payloadFormatVersion: ReferenceDataSyncService.payloadFormatVersion
            )
        )
        let client = FakeReferenceDataFetching()
        client.manifestResult = .success(makeManifest(datasets: [makeEntry(dataset: "ports", version: "v2", itemCount: 2)]))
        client.portsResult = .success([PortOption(id: "1", name: "Aberdeen"), PortOption(id: "2", name: "Plymouth")])
        let sut = ReferenceDataSyncService(client: client, store: store)

        let report = await sut.sync()

        XCTAssertEqual(report.results["ports"], .updated)
        let persisted = try await store.items(for: .ports)
        XCTAssertEqual(persisted.count, 2)
    }

    // MARK: Independent per-dataset failure

    func test_sync_oneDatasetFails_othersStillSucceed_andReportIndependently() async throws {
        let store = try makeStore()
        let client = FakeReferenceDataFetching()
        client.manifestResult = .success(makeFullManifest())
        client.portsResult = .success([PortOption(id: "1", name: "Aberdeen")])
        client.speciesResult = .success([SpeciesOption(id: "1", name: "Cod")])
        client.vesselsResult = .success([VesselOption(id: "1", name: "ACHILLES")])
        client.gearsResult = .failure(APIError.response(status: 500, details: nil))
        let sut = ReferenceDataSyncService(client: client, store: store)

        let report = await sut.sync()

        XCTAssertEqual(report.results["ports"], .updated)
        XCTAssertTrue(report.hasFailure)
        XCTAssertFalse(report.isFullSuccess)
        guard case .failed = report.results["gears"] else {
            return XCTFail("Expected gears to report .failed, got \(String(describing: report.results["gears"]))")
        }
    }

    func test_sync_failedDataset_keepsItsExistingSnapshotUntouched() async throws {
        let store = try makeStore()
        let originalPayload = Data("original".utf8)
        try await store.replace(
            dataset: .gears,
            items: [ReferenceDataStore.ItemPayload(itemID: "TBB", sortName: "Beam trawl", payload: originalPayload)],
            state: ReferenceDataStore.StateSnapshot(
                collectionId: "c1", version: "v1", schemaVersion: "1.0", itemCount: 1,
                lastModified: "2026-01-01T00:00:00Z", syncedAt: Date(),
                payloadFormatVersion: ReferenceDataSyncService.payloadFormatVersion
            )
        )
        let client = FakeReferenceDataFetching()
        // A manifest entry whose version has moved on, so the service attempts to refetch gears —
        // but the fetch itself fails, so the existing snapshot above must survive untouched.
        client.manifestResult = .success(makeManifest(datasets: [makeEntry(dataset: "gears", version: "v2", itemCount: 2)]))
        client.gearsResult = .failure(APIError.response(status: 500, details: nil))
        let sut = ReferenceDataSyncService(client: client, store: store)

        let report = await sut.sync()

        guard case .failed = report.results["gears"] else {
            return XCTFail("Expected gears to report .failed")
        }
        let persisted = try await store.items(for: .gears)
        XCTAssertEqual(persisted, [originalPayload], "A failed refetch must never touch the existing snapshot")
    }

    func test_sync_failedValidation_reportsFailed_keepsExistingSnapshot() async throws {
        let store = try makeStore()
        let client = FakeReferenceDataFetching()
        client.manifestResult = .success(makeFullManifest())
        client.portsResult = .success([PortOption(id: "1", name: "Aberdeen"), PortOption(id: "1", name: "Duplicate")])
        client.speciesResult = .success([SpeciesOption(id: "1", name: "Cod")])
        client.vesselsResult = .success([VesselOption(id: "1", name: "ACHILLES")])
        client.gearsResult = .success([GearOption(id: "TBB", name: "Beam trawl")])
        let sut = ReferenceDataSyncService(client: client, store: store)

        let report = await sut.sync()

        guard case .failed = report.results["ports"] else {
            return XCTFail("Expected ports to report .failed for a duplicate-identifier validation error")
        }
        let persisted = try await store.items(for: .ports)
        XCTAssertTrue(persisted.isEmpty, "Never persisted in the first place")
    }

    // MARK: Manifest fetch itself fails

    func test_sync_manifestFetchFails_withNoExistingState_attemptsABlindRefetch() async throws {
        let store = try makeStore()
        let client = FakeReferenceDataFetching()
        client.manifestResult = .failure(APIError.response(status: 503, details: nil))
        client.portsResult = .success([PortOption(id: "1", name: "Aberdeen")])
        client.speciesResult = .success([SpeciesOption(id: "1", name: "Cod")])
        client.vesselsResult = .success([VesselOption(id: "1", name: "ACHILLES")])
        client.gearsResult = .success([GearOption(id: "TBB", name: "Beam trawl")])
        let sut = ReferenceDataSyncService(client: client, store: store)

        let report = await sut.sync()

        XCTAssertEqual(report.results["ports"], .updated)
    }

    func test_sync_manifestFetchFails_withExistingState_reportsUnchanged_doesNotRefetch() async throws {
        let store = try makeStore()
        try await store.replace(
            dataset: .ports,
            items: [ReferenceDataStore.ItemPayload(itemID: "1", sortName: "Aberdeen", payload: Data())],
            state: ReferenceDataStore.StateSnapshot(
                collectionId: "c1", version: "v1", schemaVersion: "1.0", itemCount: 1,
                lastModified: "2026-01-01T00:00:00Z", syncedAt: Date(),
                payloadFormatVersion: ReferenceDataSyncService.payloadFormatVersion
            )
        )
        let client = FakeReferenceDataFetching()
        client.manifestResult = .failure(APIError.response(status: 503, details: nil))
        client.portsResult = .failure(APIError.response(status: 500, details: nil))
        let sut = ReferenceDataSyncService(client: client, store: store)

        let report = await sut.sync()

        XCTAssertEqual(report.results["ports"], .unchanged)
    }

    // MARK: Payload-format version bump forces a refetch

    func test_sync_payloadFormatVersionMismatch_forcesARefetch_evenWhenManifestUnchanged() async throws {
        let store = try makeStore()
        try await store.replace(
            dataset: .ports,
            items: [ReferenceDataStore.ItemPayload(itemID: "1", sortName: "Aberdeen", payload: Data())],
            state: ReferenceDataStore.StateSnapshot(
                collectionId: "c1", version: "v1", schemaVersion: "1.0", itemCount: 1,
                lastModified: "2026-01-01T00:00:00Z", syncedAt: Date(),
                payloadFormatVersion: 0 // stale — current is `ReferenceDataSyncService.payloadFormatVersion`
            )
        )
        let client = FakeReferenceDataFetching()
        client.manifestResult = .success(makeManifest(datasets: [makeEntry(dataset: "ports", itemCount: 1)]))
        client.portsResult = .success([PortOption(id: "1", name: "Aberdeen")])
        let sut = ReferenceDataSyncService(client: client, store: store)

        let report = await sut.sync()

        XCTAssertEqual(report.results["ports"], .updated)
    }
}
