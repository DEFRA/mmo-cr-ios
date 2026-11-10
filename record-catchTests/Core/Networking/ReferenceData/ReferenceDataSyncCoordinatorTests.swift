//
//  ReferenceDataSyncCoordinatorTests.swift
//  record-catchTests
//
//  Covers `ReferenceDataSyncCoordinator`'s triggers/throttle/status logic (see ADR-0024
//  "Triggers"/"Error UI"/"Sign-out") against a real `ReferenceDataSyncService` + in-memory
//  `ReferenceDataStore`, with a configurable fake `ReferenceDataFetching` double (see
//  `ReferenceDataSyncServiceTests.swift`'s file header for why `StubReferenceDataClient` isn't
//  reused). `attemptSync` is fire-and-forget (`Task { ... }`, no completion hook exposed to
//  callers — matching `ReferenceDataSyncCoordinator`'s real call sites, which only ever observe
//  `status` changing), so these tests poll `status`/`fetchManifestCallCount` with a short bounded
//  wait rather than a fixed `sleep` — the closest approximation to "wait for an expectation" this
//  fire-and-forget design allows.
//

import XCTest
import SwiftData
@testable import record_catch

private final class FakeReferenceDataFetching: ReferenceDataFetching, @unchecked Sendable {
    var manifestResult: Result<ReferenceDataManifest, Error> = .success(
        ReferenceDataManifest(manifestId: "00000000-0000-4000-8000-000000000001", version: "v1", datasets: [])
    )
    /// When `true`, every dataset fetch also fails — paired with a failing `manifestResult` so a
    /// sync can be made to genuinely fail end-to-end (a failing manifest alone is not enough: the
    /// service falls back to a blind per-dataset refetch, which these fakes' otherwise-successful
    /// fetch methods would satisfy).
    var allFetchesFail = false
    private let lock = NSLock()
    private var _fetchManifestCallCount = 0
    var fetchManifestCallCount: Int { lock.withLock { _fetchManifestCallCount } }

    func fetchVessels() async throws -> [VesselOption] {
        if allFetchesFail { throw APIError.response(status: 500, details: nil) }
        return [VesselOption(id: "1", name: "ACHILLES")]
    }
    func fetchVessel(id _: String) async throws -> VesselOption { throw APIError.response(status: 404, details: nil) }
    func fetchSpecies() async throws -> [SpeciesOption] {
        if allFetchesFail { throw APIError.response(status: 500, details: nil) }
        return [SpeciesOption(id: "1", name: "Cod")]
    }
    func fetchSpecies(id _: String) async throws -> SpeciesOption { throw APIError.response(status: 404, details: nil) }
    func fetchPorts() async throws -> [PortOption] {
        if allFetchesFail { throw APIError.response(status: 500, details: nil) }
        return [PortOption(id: "1", name: "Aberdeen")]
    }
    func fetchPort(id _: String) async throws -> PortOption { throw APIError.response(status: 404, details: nil) }
    func fetchGears() async throws -> [GearOption] {
        if allFetchesFail { throw APIError.response(status: 500, details: nil) }
        return [GearOption(id: "TBB", name: "Beam trawl")]
    }
    func fetchManifest() async throws -> ReferenceDataManifest {
        lock.withLock { _fetchManifestCallCount += 1 }
        return try manifestResult.get()
    }
    func checkHealth() async throws {}
}

@MainActor
final class ReferenceDataSyncCoordinatorTests: XCTestCase {

    private func makeStore() throws -> ReferenceDataStore {
        let container = try ModelContainer(
            for: ReferenceItemEntity.self, ReferenceDatasetStateEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ReferenceDataStore(modelContainer: container)
    }

    private func makeSUT(
        isOnline: Bool = true,
        isUITesting: Bool = false,
        now: @escaping () -> Date = Date.init
    ) throws -> (ReferenceDataSyncCoordinator, FakeReferenceDataFetching) {
        let client = FakeReferenceDataFetching()
        let service = ReferenceDataSyncService(client: client, store: try makeStore())
        let sut = ReferenceDataSyncCoordinator(service: service, isOnline: { isOnline }, now: now, isUITesting: isUITesting)
        return (sut, client)
    }

    /// Polls until `predicate()` is true or `timeout` elapses — see file header for why this
    /// (rather than a fixed `sleep`) is used to observe the fire-and-forget sync `Task`.
    private func waitUntil(timeout: TimeInterval = 2, _ predicate: () -> Bool) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !predicate(), Date() < deadline {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    // MARK: Initial state

    func test_init_statusIsIdle() throws {
        let (sut, _) = try makeSUT()

        XCTAssertEqual(sut.status, .idle)
    }

    // MARK: Offline — every trigger is a no-op

    func test_notifyReachedHome_whenOffline_neverAttemptsSync() async throws {
        let (sut, client) = try makeSUT(isOnline: false)

        sut.notifyReachedHome()
        await waitUntil { client.fetchManifestCallCount > 0 }

        XCTAssertEqual(client.fetchManifestCallCount, 0)
        XCTAssertEqual(sut.status, .idle)
    }

    // MARK: UI test launches never sync

    func test_notifyReachedHome_duringUITesting_neverAttemptsSync() async throws {
        let (sut, client) = try makeSUT(isUITesting: true)

        sut.notifyReachedHome()
        await waitUntil { client.fetchManifestCallCount > 0 }

        XCTAssertEqual(client.fetchManifestCallCount, 0)
    }

    // MARK: Online — a trigger attempts a sync and resolves to idle on success

    func test_notifyReachedHome_whenOnline_attemptsSync_andResolvesToIdleOnSuccess() async throws {
        let (sut, client) = try makeSUT()

        sut.notifyReachedHome()
        await waitUntil { sut.status == .idle && client.fetchManifestCallCount > 0 }

        XCTAssertEqual(client.fetchManifestCallCount, 1)
        XCTAssertEqual(sut.status, .idle)
    }

    func test_sync_whenManifestFails_resolvesToFailedStatus_withNoLocalData() async throws {
        let (sut, client) = try makeSUT()
        client.manifestResult = .failure(APIError.response(status: 503, details: nil))
        // A failing manifest alone isn't enough to fail the sync: with no local state yet, the
        // service falls back to a blind per-dataset refetch (see `ReferenceDataSyncService
        // .syncDataset`), which these fakes' otherwise-successful fetch methods would satisfy.
        client.allFetchesFail = true

        sut.notifyReachedHome()
        await waitUntil { if case .failed = sut.status { return true } else { return false } }

        XCTAssertEqual(sut.status, .failed(hasLocalData: false))
    }

    // MARK: Throttle

    func test_notifyForeground_withinThrottleWindow_doesNotAttemptASecondSync() async throws {
        var now = Date()
        let (sut, client) = try makeSUT(now: { now })
        sut.notifyReachedHome()
        await waitUntil { sut.status == .idle && client.fetchManifestCallCount > 0 }
        XCTAssertEqual(client.fetchManifestCallCount, 1)

        now = now.addingTimeInterval(60) // well within the 15-minute throttle
        sut.notifyForeground()
        await waitUntil(timeout: 0.3) { client.fetchManifestCallCount > 1 }

        XCTAssertEqual(client.fetchManifestCallCount, 1, "A second attempt inside the throttle window must be a no-op")
    }

    func test_notifyForeground_afterThrottleIntervalElapses_attemptsAnotherSync() async throws {
        var now = Date()
        let (sut, client) = try makeSUT(now: { now })
        sut.notifyReachedHome()
        await waitUntil { sut.status == .idle && client.fetchManifestCallCount > 0 }

        now = now.addingTimeInterval(ReferenceDataSyncCoordinator.throttleInterval + 1)
        sut.notifyForeground()
        await waitUntil { client.fetchManifestCallCount > 1 }

        XCTAssertEqual(client.fetchManifestCallCount, 2)
    }

    func test_retry_alwaysBypassesTheThrottle() async throws {
        var now = Date()
        let (sut, client) = try makeSUT(now: { now })
        sut.notifyReachedHome()
        await waitUntil { sut.status == .idle && client.fetchManifestCallCount > 0 }

        now = now.addingTimeInterval(1) // nowhere near the throttle interval
        sut.retry()
        await waitUntil { client.fetchManifestCallCount > 1 }

        XCTAssertEqual(client.fetchManifestCallCount, 2)
    }

    // MARK: dismissError

    func test_dismissError_whenFailed_resetsStatusToIdle() async throws {
        let (sut, client) = try makeSUT()
        client.manifestResult = .failure(APIError.response(status: 503, details: nil))
        sut.notifyReachedHome()
        await waitUntil { if case .failed = sut.status { return true } else { return false } }

        sut.dismissError()

        XCTAssertEqual(sut.status, .idle)
    }

    func test_dismissError_whenNotFailed_isANoOp() throws {
        let (sut, _) = try makeSUT()

        sut.dismissError()

        XCTAssertEqual(sut.status, .idle)
    }

    // MARK: resetForSignOut

    func test_resetForSignOut_clearsThrottle_soTheNextReachedHomeAttemptsImmediately() async throws {
        var now = Date()
        let (sut, client) = try makeSUT(now: { now })
        sut.notifyReachedHome()
        await waitUntil { sut.status == .idle && client.fetchManifestCallCount > 0 }

        sut.resetForSignOut()
        now = now.addingTimeInterval(1) // nowhere near the throttle interval, but reset clears it anyway
        sut.notifyForeground()
        await waitUntil { client.fetchManifestCallCount > 1 }

        XCTAssertEqual(client.fetchManifestCallCount, 2)
    }

    func test_resetForSignOut_setsStatusToIdle() async throws {
        let (sut, client) = try makeSUT()
        client.manifestResult = .failure(APIError.response(status: 503, details: nil))
        sut.notifyReachedHome()
        await waitUntil { if case .failed = sut.status { return true } else { return false } }

        sut.resetForSignOut()

        XCTAssertEqual(sut.status, .idle)
    }
}
