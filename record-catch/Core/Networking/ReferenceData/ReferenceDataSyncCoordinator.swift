//
//  ReferenceDataSyncCoordinator.swift
//  record-catch
//
//  Owns *when* a reference-data sync runs and the resulting UI-facing status (see ADR-0024
//  "Triggers" and "Error UI"). `ReferenceDataSyncService` does the actual fetch/validate/persist
//  work off the main actor; this `@MainActor` façade decides whether to call it at all
//  (connectivity, throttling, UI-test seam) and tracks `status` for `SyncErrorBanner`/
//  `ReferenceDataUnavailableView` to render.
//
//  `ReferenceDataSyncStatus`, `ReferenceDataSyncStatusObserving` and
//  `StubReferenceDataSyncStatusObserver` live in `ReferenceDataSyncStatusEnvironment.swift`, not
//  here — see that file's doc comment for why (keeps `SyncErrorBanner`'s direct test-target
//  compilation dependency-light, mirroring `ConnectivityMonitoring.swift`'s role for
//  `OfflineBanner`).
//

import Foundation

/// Drives `ReferenceDataSyncService` from the app's lifecycle triggers (see ADR-0024
/// "Triggers"): reaching Home after sign-in/unlock (bypasses the throttle — the user has just
/// authenticated, so a fresh token is available and a first-ever sync must not wait 15 minutes),
/// returning to the foreground, and the connection coming back online. Never runs during
/// `-uiTest*` launches (see `LaunchArguments.isUITesting`) — no XCUITest run should ever depend on
/// live network access to the reference-data API.
@MainActor
@Observable
final class ReferenceDataSyncCoordinator: ReferenceDataSyncStatusObserving {

    /// Minimum time between two non-bypassing sync attempts (see ADR-0024 "Triggers").
    static let throttleInterval: TimeInterval = 15 * 60

    private(set) var status: ReferenceDataSyncStatus = .idle

    private let service: ReferenceDataSyncService
    private let isOnline: () -> Bool
    private let now: () -> Date
    private let isUITesting: Bool
    private var lastSyncStartedAt: Date?
    private var isSyncing = false

    init(
        service: ReferenceDataSyncService,
        isOnline: @escaping () -> Bool,
        now: @escaping () -> Date = Date.init,
        isUITesting: Bool = LaunchArguments.current.isUITesting
    ) {
        self.service = service
        self.isOnline = isOnline
        self.now = now
        self.isUITesting = isUITesting
    }

    /// Call when the root session reaches `.home` (a fresh sign-in, or a launch/unlock with an
    /// existing session) — bypasses the throttle.
    func notifyReachedHome() {
        attemptSync(bypassThrottle: true)
    }

    /// Call when the scene returns to the foreground after backgrounding.
    func notifyForeground() {
        attemptSync(bypassThrottle: false)
    }

    /// Call when `ConnectivityMonitoring.isOnline` transitions from `false` to `true`.
    func notifyConnectivityRestored() {
        attemptSync(bypassThrottle: false)
    }

    /// User-initiated retry from `SyncErrorBanner`/`ReferenceDataUnavailableView` — always bypasses
    /// the throttle, since the user explicitly asked for another attempt.
    func retry() {
        attemptSync(bypassThrottle: true)
    }

    /// Dismisses a `.failed` banner without retrying (see ADR-0024 "Error UI") — returns to
    /// `.idle` so the banner disappears; the next trigger (foreground/reconnect/throttle elapsing)
    /// will attempt another sync regardless.
    func dismissError() {
        guard case .failed = status else { return }
        status = .idle
    }

    /// Resets throttle/in-flight state on sign-out (see ADR-0024 "Sign-out") — reference data
    /// itself is *not* cleared (it isn't personal data), but the next sign-in's `notifyReachedHome()`
    /// should not be suppressed by a stale throttle timestamp from the previous session.
    func resetForSignOut() {
        lastSyncStartedAt = nil
        isSyncing = false
        status = .idle
    }

    private func attemptSync(bypassThrottle: Bool) {
        guard !isUITesting, !isSyncing, isOnline() else { return }
        if !bypassThrottle, let lastSyncStartedAt, now().timeIntervalSince(lastSyncStartedAt) < Self.throttleInterval {
            return
        }

        isSyncing = true
        lastSyncStartedAt = now()
        status = .syncing

        Task { [weak self] in
            guard let self else { return }
            let report = await service.sync()
            await MainActor.run {
                self.handle(report: report)
            }
        }
    }

    private func handle(report: ReferenceDataSyncReport) {
        isSyncing = false
        guard report.hasFailure else {
            status = .idle
            return
        }
        Task { [weak self] in
            guard let self else { return }
            let hasLocalData = await service.hasAnyData()
            await MainActor.run {
                self.status = .failed(hasLocalData: hasLocalData)
            }
        }
    }
}

// MARK: - Factory

extension ReferenceDataSyncCoordinator {
    /// Builds the production coordinator for `RecordCatchApp`: a `RemoteReferenceDataClient` over
    /// a fresh `URLSessionHTTPClient`, wrapping `store` in a `ReferenceDataSyncService`, and bound
    /// to `connectivityMonitor.isOnline` (see ADR-0024 "Triggers").
    ///
    /// - Note (known gap — ADR-0024 "Known gap — production bearer token"): `AuthTokenProviding`
    ///   has no production (Keychain/MSAL-backed) implementation yet — outside `DEBUG`/
    ///   `ENABLE_DEBUG_REFERENCE_DATA_TOOL` this resolves to `NilAuthTokenProvider`, so every
    ///   request is sent unauthenticated. If the live API requires a bearer token, every sync
    ///   attempt reports `.failed` uniformly (`SyncErrorBanner` shows, the app keeps working with
    ///   whatever is already on-device) rather than crashing — a safe degradation, not silent data
    ///   loss, but production bearer-token support must land before this ships to real users.
    /// - Parameter connectivityMonitor: kept weak inside the returned coordinator's `isOnline`
    ///   closure — matches `RootSessionCoordinator.make(connectivityMonitor:)`'s pattern of reusing
    ///   the app's single `NWPathMonitor`-backed instance rather than constructing a second one.
    @MainActor
    static func make(
        store: ReferenceDataStore,
        connectivityMonitor: any ConnectivityMonitoring
    ) -> ReferenceDataSyncCoordinator {
        let client: any ReferenceDataFetching
        do {
            client = RemoteReferenceDataClient(
                httpClient: URLSessionHTTPClient(),
                configuration: try APIConfiguration(),
                tokenProvider: makeTokenProvider()
            )
        } catch {
            client = FailingReferenceDataClient()
        }
        let service = ReferenceDataSyncService(client: client, store: store)
        return ReferenceDataSyncCoordinator(
            service: service,
            isOnline: { [weak connectivityMonitor] in connectivityMonitor?.isOnline ?? true }
        )
    }

    private static func makeTokenProvider() -> any AuthTokenProviding {
        #if DEBUG || ENABLE_DEBUG_REFERENCE_DATA_TOOL
        EnvironmentTokenProvider()
        #else
        NilAuthTokenProvider()
        #endif
    }
}
