//
//  NetworkConnectivityMonitorTests.swift
//  record-catchTests
//
//  Exercises `NetworkConnectivityMonitor`'s status-mapping logic end to end via a fake
//  `PathStatusSource` (see ADR-0019) — never a real `NWPathMonitor`/`NWPath`, which cannot be
//  constructed or driven deterministically in a test.
//

import XCTest
import Network
@testable import record_catch

/// Deterministic, test-controlled `PathStatusSource`. Lets a test seed the initial status and
/// then drip-feed subsequent statuses through `yield(_:)`.
private final class FakePathStatusSource: PathStatusSource, @unchecked Sendable {
    let currentStatus: NWPath.Status
    private let stream: AsyncStream<NWPath.Status>
    private let continuation: AsyncStream<NWPath.Status>.Continuation

    init(currentStatus: NWPath.Status) {
        self.currentStatus = currentStatus
        (stream, continuation) = AsyncStream.makeStream()
    }

    func statusUpdates() -> AsyncStream<NWPath.Status> { stream }

    func yield(_ status: NWPath.Status) {
        continuation.yield(status)
    }

    func finish() {
        continuation.finish()
    }
}

@MainActor
final class NetworkConnectivityMonitorTests: XCTestCase {

    // MARK: - Seeding

    func test_init_whenCurrentStatusSatisfied_seedsIsOnlineTrue() {
        let monitor = NetworkConnectivityMonitor(source: FakePathStatusSource(currentStatus: .satisfied))
        XCTAssertTrue(monitor.isOnline)
    }

    func test_init_whenCurrentStatusUnsatisfied_seedsIsOnlineFalse() {
        let monitor = NetworkConnectivityMonitor(source: FakePathStatusSource(currentStatus: .unsatisfied))
        XCTAssertFalse(monitor.isOnline)
    }

    // MARK: - apply(_:) mapping

    func test_apply_satisfied_setsIsOnlineTrue() {
        let monitor = NetworkConnectivityMonitor(source: FakePathStatusSource(currentStatus: .unsatisfied))
        monitor.apply(.satisfied)
        XCTAssertTrue(monitor.isOnline)
    }

    func test_apply_unsatisfied_setsIsOnlineFalse() {
        let monitor = NetworkConnectivityMonitor(source: FakePathStatusSource(currentStatus: .satisfied))
        monitor.apply(.unsatisfied)
        XCTAssertFalse(monitor.isOnline)
    }

    func test_apply_requiresConnection_isTreatedAsOffline() {
        let monitor = NetworkConnectivityMonitor(source: FakePathStatusSource(currentStatus: .satisfied))
        monitor.apply(.requiresConnection)
        XCTAssertFalse(monitor.isOnline)
    }

    func test_apply_sameStatusTwice_isIdempotent() {
        let monitor = NetworkConnectivityMonitor(source: FakePathStatusSource(currentStatus: .satisfied))
        monitor.apply(.satisfied)
        XCTAssertTrue(monitor.isOnline)
    }

    // MARK: - start() end-to-end via the fake source

    func test_start_whenSourceEmitsUnsatisfied_updatesIsOnlineToFalse() async {
        let source = FakePathStatusSource(currentStatus: .satisfied)
        let monitor = NetworkConnectivityMonitor(source: source)
        monitor.start()

        source.yield(.unsatisfied)
        await Task.yield()
        // Allow the observation Task's loop iteration to run.
        try? await Task.sleep(for: .milliseconds(50))

        XCTAssertFalse(monitor.isOnline)
        monitor.stop()
    }

    func test_start_calledTwice_doesNotDuplicateObservation() async {
        let source = FakePathStatusSource(currentStatus: .satisfied)
        let monitor = NetworkConnectivityMonitor(source: source)
        monitor.start()
        monitor.start() // second call should be a no-op, not a crash or duplicate subscription

        source.yield(.unsatisfied)
        try? await Task.sleep(for: .milliseconds(50))

        XCTAssertFalse(monitor.isOnline)
        monitor.stop()
    }

    func test_stop_afterStop_isOnlineStopsUpdating() async {
        let source = FakePathStatusSource(currentStatus: .satisfied)
        let monitor = NetworkConnectivityMonitor(source: source)
        monitor.start()
        monitor.stop()

        source.yield(.unsatisfied)
        try? await Task.sleep(for: .milliseconds(50))

        // The observation task was cancelled before the update arrived, so the seeded value
        // should still hold.
        XCTAssertTrue(monitor.isOnline)
    }
}
