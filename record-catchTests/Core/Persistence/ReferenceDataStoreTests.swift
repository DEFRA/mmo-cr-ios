//
//  ReferenceDataStoreTests.swift
//  record-catchTests
//
//  Covers `ReferenceDataStore` against a real, in-memory `ModelContainer` (see ADR-0024 "SwiftData
//  models"/"Atomic replace"), mirroring `SwiftDataFavouriteProvidersTests`'s pattern.
//

import XCTest
import SwiftData
@testable import record_catch

final class ReferenceDataStoreTests: XCTestCase {

    private func makeStore() throws -> ReferenceDataStore {
        let container = try ModelContainer(
            for: ReferenceItemEntity.self, ReferenceDatasetStateEntity.self, ReferenceBlobEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ReferenceDataStore(modelContainer: container)
    }

    private func makeState(
        collectionId: String = "c1",
        version: String = "v1",
        schemaVersion: String = "1.0",
        itemCount: Int? = 2,
        payloadFormatVersion: Int = 1
    ) -> ReferenceDataStore.StateSnapshot {
        ReferenceDataStore.StateSnapshot(
            collectionId: collectionId,
            version: version,
            schemaVersion: schemaVersion,
            itemCount: itemCount,
            lastModified: "2026-01-01T00:00:00Z",
            syncedAt: Date(),
            payloadFormatVersion: payloadFormatVersion
        )
    }

    private func makeItems(_ names: [String]) -> [ReferenceDataStore.ItemPayload] {
        names.map { ReferenceDataStore.ItemPayload(itemID: $0, sortName: $0, payload: Data($0.utf8)) }
    }

    // MARK: state / hasData / hasAnyData — before any sync

    func test_state_returnsNil_beforeAnySync() async throws {
        let sut = try makeStore()

        let state = try await sut.state(for: .ports)

        XCTAssertNil(state)
    }

    func test_hasData_isFalse_beforeAnySync() async throws {
        let sut = try makeStore()

        let hasData = try await sut.hasData(for: .ports)
        XCTAssertFalse(hasData)
    }

    func test_hasAnyData_isFalse_beforeAnySync() async throws {
        let sut = try makeStore()

        let hasAnyData = try await sut.hasAnyData()
        XCTAssertFalse(hasAnyData)
    }

    // MARK: replace — first write

    func test_replace_persistsItems_retrievableBySortName() async throws {
        let sut = try makeStore()

        try await sut.replace(dataset: .ports, items: makeItems(["Plymouth", "Aberdeen"]), state: makeState())

        let items = try await sut.items(for: .ports)
        // Alphabetised by sortName (see `replace`'s doc comment), not insertion order.
        XCTAssertEqual(items.map { String(data: $0, encoding: .utf8) }, ["Aberdeen", "Plymouth"])
    }

    func test_replace_persistsState_retrievableByState() async throws {
        let sut = try makeStore()
        let state = makeState(collectionId: "c1", version: "v2", itemCount: 1)

        try await sut.replace(dataset: .species, items: makeItems(["Cod"]), state: state)

        let fetched = try await sut.state(for: .species)
        XCTAssertEqual(fetched, state)
    }

    func test_replace_setsHasData_andHasAnyData_true() async throws {
        let sut = try makeStore()

        try await sut.replace(dataset: .gears, items: makeItems(["Beam trawl"]), state: makeState())

        let hasGearsData = try await sut.hasData(for: .gears)
        let hasAnyData = try await sut.hasAnyData()
        let hasPortsData = try await sut.hasData(for: .ports)
        XCTAssertTrue(hasGearsData)
        XCTAssertTrue(hasAnyData)
        XCTAssertFalse(hasPortsData, "Only the replaced dataset should report data")
    }

    // MARK: replace — a second call fully replaces, never merges

    func test_replace_calledTwice_removesPreviousItems_notJustAppends() async throws {
        let sut = try makeStore()
        try await sut.replace(dataset: .ports, items: makeItems(["Plymouth"]), state: makeState())

        try await sut.replace(dataset: .ports, items: makeItems(["Aberdeen"]), state: makeState())

        let items = try await sut.items(for: .ports)
        XCTAssertEqual(items.map { String(data: $0, encoding: .utf8) }, ["Aberdeen"])
    }

    func test_replace_calledTwice_updatesState_ratherThanDuplicatingTheRow() async throws {
        let sut = try makeStore()
        try await sut.replace(dataset: .ports, items: makeItems(["Plymouth"]), state: makeState(version: "v1"))

        try await sut.replace(dataset: .ports, items: makeItems(["Plymouth"]), state: makeState(version: "v2"))

        let state = try await sut.state(for: .ports)
        XCTAssertEqual(state?.version, "v2")
    }

    func test_replace_withEmptyItems_clearsTheDataset_butKeepsItsState() async throws {
        let sut = try makeStore()
        try await sut.replace(dataset: .ports, items: makeItems(["Plymouth"]), state: makeState())

        try await sut.replace(dataset: .ports, items: [], state: makeState())

        let items = try await sut.items(for: .ports)
        XCTAssertTrue(items.isEmpty)
        let state = try await sut.state(for: .ports)
        XCTAssertNotNil(state)
    }

    // MARK: datasets are independent

    func test_replace_forOneDataset_doesNotAffectAnother() async throws {
        let sut = try makeStore()
        try await sut.replace(dataset: .ports, items: makeItems(["Plymouth"]), state: makeState())

        try await sut.replace(dataset: .species, items: makeItems(["Cod"]), state: makeState())

        let ports = try await sut.items(for: .ports)
        XCTAssertEqual(ports.map { String(data: $0, encoding: .utf8) }, ["Plymouth"])
    }

    // MARK: - decodedItems(for:as:) (ADR-0024 "Consumers")

    private func makePortPayloads(_ ports: [PortOption]) -> [ReferenceDataStore.ItemPayload] {
        let encoder = JSONEncoder()
        return ports.map {
            ReferenceDataStore.ItemPayload(itemID: $0.id, sortName: $0.name, payload: try! encoder.encode($0))
        }
    }

    func test_decodedItems_returnsEmpty_beforeAnySync() async throws {
        let sut = try makeStore()

        let ports: [PortOption] = try await sut.decodedItems(for: .ports, as: PortOption.self)

        XCTAssertTrue(ports.isEmpty)
    }

    func test_decodedItems_decodesEveryPersistedItem_alphabetisedBySortName() async throws {
        let sut = try makeStore()
        let plymouth = PortOption(id: "1", name: "Plymouth")
        let aberdeen = PortOption(id: "2", name: "Aberdeen")
        try await sut.replace(dataset: .ports, items: makePortPayloads([plymouth, aberdeen]), state: makeState())

        let decoded: [PortOption] = try await sut.decodedItems(for: .ports, as: PortOption.self)

        XCTAssertEqual(decoded, [aberdeen, plymouth])
    }

    func test_decodedItems_skipsARowThatFailsToDecode_ratherThanFailingTheWholeRead() async throws {
        let sut = try makeStore()
        let plymouth = PortOption(id: "1", name: "Plymouth")
        var payloads = makePortPayloads([plymouth])
        payloads.append(ReferenceDataStore.ItemPayload(itemID: "bad", sortName: "Zzz", payload: Data("not json".utf8)))
        try await sut.replace(dataset: .ports, items: payloads, state: makeState())

        let decoded: [PortOption] = try await sut.decodedItems(for: .ports, as: PortOption.self)

        XCTAssertEqual(decoded, [plymouth])
    }

    // MARK: - Blob datasets (map-land / map-statistical-areas — see ADR-0024 "Map data")

    func test_blobState_returnsNil_beforeAnySync() async throws {
        let sut = try makeStore()

        let state = try await sut.blobState(for: .mapLand)

        XCTAssertNil(state)
    }

    func test_hasBlob_isFalse_beforeAnySync() async throws {
        let sut = try makeStore()

        let hasBlob = try await sut.hasBlob(for: .mapLand)
        XCTAssertFalse(hasBlob)
    }

    func test_blob_returnsNil_beforeAnySync() async throws {
        let sut = try makeStore()

        let blob = try await sut.blob(for: .mapLand)
        XCTAssertNil(blob)
    }

    func test_replaceBlob_persistsPayload_retrievableByBlob() async throws {
        let sut = try makeStore()
        let payload = Data(#"{"type":"FeatureCollection","features":[]}"#.utf8)

        try await sut.replaceBlob(dataset: .mapLand, payload: payload, state: makeState())

        let fetched = try await sut.blob(for: .mapLand)
        XCTAssertEqual(fetched, payload)
    }

    func test_replaceBlob_persistsState_retrievableByBlobState() async throws {
        let sut = try makeStore()
        let state = makeState(collectionId: "c1", version: "v2", itemCount: nil)

        try await sut.replaceBlob(dataset: .mapStatisticalAreas, payload: Data("{}".utf8), state: state)

        let fetched = try await sut.blobState(for: .mapStatisticalAreas)
        XCTAssertEqual(fetched, state)
    }

    func test_replaceBlob_setsHasBlob_andHasAnyData_true() async throws {
        let sut = try makeStore()

        try await sut.replaceBlob(dataset: .mapLand, payload: Data("{}".utf8), state: makeState())

        let hasMapLandBlob = try await sut.hasBlob(for: .mapLand)
        let hasAnyData = try await sut.hasAnyData()
        let hasStatisticalAreasBlob = try await sut.hasBlob(for: .mapStatisticalAreas)
        XCTAssertTrue(hasMapLandBlob)
        XCTAssertTrue(hasAnyData)
        XCTAssertFalse(hasStatisticalAreasBlob, "Only the replaced dataset should report data")
    }

    func test_replaceBlob_calledTwice_overwritesPayload_notJustAppends() async throws {
        let sut = try makeStore()
        try await sut.replaceBlob(dataset: .mapLand, payload: Data("first".utf8), state: makeState())

        try await sut.replaceBlob(dataset: .mapLand, payload: Data("second".utf8), state: makeState())

        let fetched = try await sut.blob(for: .mapLand)
        XCTAssertEqual(fetched, Data("second".utf8))
    }

    func test_replaceBlob_calledTwice_updatesState_ratherThanDuplicatingTheRow() async throws {
        let sut = try makeStore()
        try await sut.replaceBlob(dataset: .mapLand, payload: Data("{}".utf8), state: makeState(version: "v1"))

        try await sut.replaceBlob(dataset: .mapLand, payload: Data("{}".utf8), state: makeState(version: "v2"))

        let state = try await sut.blobState(for: .mapLand)
        XCTAssertEqual(state?.version, "v2")
    }

    func test_replaceBlob_forOneDataset_doesNotAffectAnother() async throws {
        let sut = try makeStore()
        try await sut.replaceBlob(dataset: .mapLand, payload: Data("land".utf8), state: makeState())

        try await sut.replaceBlob(dataset: .mapStatisticalAreas, payload: Data("areas".utf8), state: makeState())

        let land = try await sut.blob(for: .mapLand)
        XCTAssertEqual(land, Data("land".utf8))
    }

    func test_itemDatasetAndBlobDataset_areIndependent() async throws {
        let sut = try makeStore()
        try await sut.replace(dataset: .ports, items: makeItems(["Plymouth"]), state: makeState())

        try await sut.replaceBlob(dataset: .mapLand, payload: Data("{}".utf8), state: makeState())

        let ports = try await sut.items(for: .ports)
        let mapLand = try await sut.blob(for: .mapLand)
        XCTAssertEqual(ports.count, 1)
        XCTAssertNotNil(mapLand)
    }
}
