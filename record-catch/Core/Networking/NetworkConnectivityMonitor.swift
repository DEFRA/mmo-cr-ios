//
//  NetworkConnectivityMonitor.swift
//  record-catch
//
//  `NWPathMonitor`-backed `ConnectivityMonitoring` (see ADR-0019). Targets this app's iOS 18.0+
//  deployment floor, so `NWPathMonitor`'s native `AsyncSequence` conformance is used directly —
//  no `DispatchQueue` + `pathUpdateHandler` trampoline and no manual actor hop are needed, which
//  also removes the off-main-actor data-race hazard that approach would carry.
//

import Foundation
import Network
import OSLog

/// Minimal abstraction over `NWPathMonitor`, exposing only what `NetworkConnectivityMonitor`
/// needs: the current status and a stream of subsequent status changes.
///
/// `NWPath` has no public initialiser, so it cannot be constructed directly in a test — this seam
/// lets `NetworkConnectivityMonitorTests` drive the status-mapping logic with a fake source
/// instead, leaving only the thin `NWPathMonitorStatusSource` adapter below untested at the OS
/// boundary (see ADR-0016's scoped-coverage-exclusion policy).
protocol PathStatusSource: Sendable {
    var currentStatus: NWPath.Status { get }
    func statusUpdates() -> AsyncStream<NWPath.Status>
}

/// Default `PathStatusSource`, backed by the real `NWPathMonitor`.
struct NWPathMonitorStatusSource: PathStatusSource {
    private let monitor = NWPathMonitor()

    var currentStatus: NWPath.Status { monitor.currentPath.status }

    func statusUpdates() -> AsyncStream<NWPath.Status> {
        let monitor = self.monitor
        return AsyncStream { continuation in
            let task = Task {
                for await path in monitor {
                    continuation.yield(path.status)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in
                task.cancel()
                monitor.cancel()
            }
        }
    }
}

/// Observes the device's network path and republishes `isOnline` on the main actor.
///
/// Seeds `isOnline` from the source's `currentStatus` synchronously at `init`, so the very first
/// rendered frame already reflects reality (no "flash of offline" while the first async update is
/// awaited). Call `start()` once (from the composition root) to begin observing path changes, and
/// `stop()` to cancel.
@MainActor
@Observable
final class NetworkConnectivityMonitor: ConnectivityMonitoring {
    private static let logger = Logger(subsystem: "uk.gov.defra.record-catch", category: "connectivity")

    private(set) var isOnline: Bool
    private let source: PathStatusSource
    private var observationTask: Task<Void, Never>?

    init(source: PathStatusSource = NWPathMonitorStatusSource()) {
        self.source = source
        // Correct from the first frame: avoids a spurious "offline" flash before the first
        // `for await` iteration below has had a chance to run.
        self.isOnline = source.currentStatus == .satisfied
    }

    /// Begins observing path updates. Safe to call once; a second call is a no-op while already
    /// running. Call `stop()` for an explicit shutdown (e.g. in a test's `tearDown`); as a
    /// composition-root singleton for the app's lifetime, this instance is not expected to be
    /// deallocated in normal operation, so there is deliberately no `deinit` cleanup — a `deinit`
    /// cannot synchronously touch this `@MainActor`-isolated state anyway.
    func start() {
        guard observationTask == nil else { return }
        let source = self.source
        observationTask = Task { [weak self] in
            for await status in source.statusUpdates() {
                guard !Task.isCancelled else { return }
                self?.apply(status)
            }
        }
    }

    /// Stops observing path updates.
    func stop() {
        observationTask?.cancel()
        observationTask = nil
    }

    /// Maps a path status onto `isOnline`, applying it only on an actual change. Internal (not
    /// `private`) and synchronous, specifically so `NetworkConnectivityMonitorTests` can drive it
    /// directly with `NWPath.Status` values — the one part of this type that doesn't require a
    /// real or faked `NWPathMonitor`/`NWPath` to exercise.
    func apply(_ status: NWPath.Status) {
        let newValue = status == .satisfied
        guard newValue != isOnline else { return }
        isOnline = newValue
        // Status only — never interface names, SSIDs or addresses (security.instructions.md:
        // "never log secrets or personal data"; this is a connectivity *state* transition, not
        // user content).
        Self.logger.info("Connectivity changed: \(newValue ? "online" : "offline", privacy: .public)")
    }
}
