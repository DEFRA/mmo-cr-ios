//
//  ReferenceDataSyncStatusEnvironment.swift
//  record-catch
//
//  SwiftUI environment seam for `ReferenceDataSyncStatusObserving` (see ADR-0024 "Error UI") —
//  mirrors `ConnectivityMonitoring`'s `\.connectivityMonitor` key exactly: a protocol (not the
//  concrete `ReferenceDataSyncCoordinator`) injected via a custom environment key, because the
//  real coordinator and `StubReferenceDataSyncStatusObserver` are different concrete types.
//
//  The status enum, protocol and stub observer are kept in this file — not the real
//  `ReferenceDataSyncCoordinator` class — so `SyncErrorBanner`'s direct test-target compilation
//  (see the synchronized-group membership exceptions in `project.pbxproj`, mirroring
//  `ConnectivityMonitoring.swift`'s role for `OfflineBanner`) pulls in only this lightweight file,
//  never the full sync/persistence dependency graph the real coordinator needs.
//

import SwiftUI

/// Read-only status this coordinator exposes to the UI layer (see `SyncErrorBanner`).
nonisolated enum ReferenceDataSyncStatus: Equatable, Sendable {
    /// No sync has run yet, or the last one succeeded/was skipped and nothing needs showing.
    case idle
    case syncing
    /// The most recent sync had at least one dataset failure. `hasLocalData` distinguishes
    /// "update failed, the app can keep using what it already has" from "nothing has ever
    /// downloaded" — the two messages ADR-0024 specifies for `SyncErrorBanner`/
    /// `ReferenceDataUnavailableView`.
    case failed(hasLocalData: Bool)
}

/// Narrow protocol the UI layer depends on (mirrors `ConnectivityMonitoring`'s role) so
/// `SyncErrorBanner` and the screen-level "not yet downloaded" views can be previewed/tested
/// without the real coordinator's dependencies.
@MainActor
protocol ReferenceDataSyncStatusObserving: AnyObject {
    var status: ReferenceDataSyncStatus { get }
    func retry()
    func dismissError()
}

/// Deterministic test/preview double — mirrors `StubConnectivityMonitor`'s role.
@MainActor
@Observable
final class StubReferenceDataSyncStatusObserver: ReferenceDataSyncStatusObserving {
    var status: ReferenceDataSyncStatus
    private(set) var retryCallCount = 0
    private(set) var dismissCallCount = 0

    init(status: ReferenceDataSyncStatus = .idle) {
        self.status = status
    }

    func retry() {
        retryCallCount += 1
    }

    func dismissError() {
        dismissCallCount += 1
        status = .idle
    }
}

private struct ReferenceDataSyncStatusKey: EnvironmentKey {
    /// `nil` by default — an unconfigured context (a preview/test host that never set one) is
    /// treated as `.idle` by `SyncErrorBanner`, so the banner never spuriously appears.
    static let defaultValue: (any ReferenceDataSyncStatusObserving)? = nil
}

extension EnvironmentValues {
    /// The app-wide reference-data sync status, seeded from `ReferenceDataSyncCoordinator` in
    /// `RecordCatchApp`, or a `StubReferenceDataSyncStatusObserver` for previews/tests.
    var referenceDataSyncStatus: (any ReferenceDataSyncStatusObserving)? {
        get { self[ReferenceDataSyncStatusKey.self] }
        set { self[ReferenceDataSyncStatusKey.self] = newValue }
    }
}
