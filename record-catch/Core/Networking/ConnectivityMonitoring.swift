//
//  ConnectivityMonitoring.swift
//  record-catch
//
//  Seam for observing device internet connectivity (see ADR-0019). Defined as a protocol —
//  rather than depending on the concrete `NetworkConnectivityMonitor` everywhere — so:
//    - `OfflineBanner` (Common) can be previewed and unit-tested without a real `NWPathMonitor`.
//    - UI tests can force a deterministic offline/online state via the `-uiTestOffline` launch
//      argument (see `LaunchArguments` and `RecordCatchApp`), without touching Airplane Mode.
//    - A future offline-mutation sync engine (ADR-0019 "Follow-up") can observe the same signal
//      to trigger a flush-on-reconnect, instead of standing up a second path monitor.
//
//  Injected via `\.connectivityMonitor` (mirrors the `HeaderNavigating`/`\.headerNavigator` seam
//  in `Features/Common/Views/HeaderNavigating.swift`) rather than `.environment(_:)` on a
//  concrete type, because the real and stub implementations are different concrete types.
//

import SwiftUI

/// Whether the device currently has a usable network path. Read-only from the UI's
/// perspective — only `NetworkConnectivityMonitor` (or a test double) ever sets `isOnline`.
///
/// NOTE (ADR-0019 limitation): this reflects `NWPath.status == .satisfied` — i.e. a network
/// *interface* is up — not that a specific backend is reachable (e.g. a captive portal or a
/// down server still reports "online" here). That is an accepted limitation for this
/// presentation-only feature; see the ADR for the rationale.
@MainActor
protocol ConnectivityMonitoring: AnyObject {
    /// `true` when the device has a satisfied network path, `false` when offline.
    var isOnline: Bool { get }
}

/// Deterministic test/preview double: a settable `isOnline` with no real path monitoring.
/// `@Observable` so SwiftUI re-renders `OfflineBanner` when a test or preview flips the value.
@Observable
@MainActor
final class StubConnectivityMonitor: ConnectivityMonitoring {
    var isOnline: Bool

    init(isOnline: Bool) {
        self.isOnline = isOnline
    }
}

private struct ConnectivityMonitorKey: EnvironmentKey {
    /// `nil` by default — mirrors `HeaderNavigatorKey`'s `nil` default in
    /// `HeaderNavigating.swift`, which sidesteps needing to construct a `@MainActor`-isolated
    /// instance from this (nonisolated) `EnvironmentKey` requirement. `OfflineBanner` treats a
    /// `nil` monitor as online (renders nothing), so an unconfigured context (e.g. a preview that
    /// forgot to set one) never spuriously shows the offline banner.
    static let defaultValue: (any ConnectivityMonitoring)? = nil
}

extension EnvironmentValues {
    /// The app-wide connectivity signal. Seeded from `NetworkConnectivityMonitor` in
    /// `RecordCatchApp`, or a `StubConnectivityMonitor` for previews, unit tests, and the
    /// `-uiTestOffline` UI-test seam. `nil` (the default) is treated as online by `OfflineBanner`.
    var connectivityMonitor: (any ConnectivityMonitoring)? {
        get { self[ConnectivityMonitorKey.self] }
        set { self[ConnectivityMonitorKey.self] = newValue }
    }
}
