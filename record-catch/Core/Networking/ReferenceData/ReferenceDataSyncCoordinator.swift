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

    /// Datasets that must have at least one synced item before Home can be shown (see ADR-0024
    /// "Data before Home"): ports/species/gears only. Vessels are deliberately excluded — no
    /// picker reads them yet — and so are the map blob datasets, since they aren't required by
    /// any wired feature and the backend may not serve them yet.
    static let requiredKinds: [ReferenceDataKind] = [.ports, .species, .gears]

    private(set) var status: ReferenceDataSyncStatus = .idle

    private let service: ReferenceDataSyncService
    private let isOnline: () -> Bool
    private let now: () -> Date
    private let isUITesting: Bool
    private var lastSyncStartedAt: Date?
    private var isSyncing = false
    private var inFlightSync: Task<Void, Never>?

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

    /// Whether the device currently has a network path — exposed so `DataPreparationViewModel`
    /// can choose its offline-specific message without needing its own `ConnectivityMonitoring`
    /// reference.
    var isDeviceOnline: Bool { isOnline() }

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

    /// Whether every dataset in `requiredKinds` already has at least one synced item on this
    /// device.
    func hasRequiredData() async -> Bool {
        await service.hasData(for: Self.requiredKinds)
    }

    /// Attempts a sync (bypassing the throttle, like `retry()`), waits for it to finish or for
    /// `timeout` to elapse, then reports whether every required dataset now has data. Used by
    /// `DataPreparationViewModel` to gate the move from sign-in/unlock to Home (see ADR-0024 "Data
    /// before Home"). Never actually syncs during `-uiTest*` launches — defensive, since the root
    /// session skips the `.preparingData` phase entirely in that case (see
    /// `RootSessionCoordinator`), so this method is not the primary UI-test seam.
    func prepareRequiredData(timeout: TimeInterval = 20) async -> Bool {
        guard !isUITesting else { return true }
        if let task = attemptSync(bypassThrottle: true) {
            await Self.wait(for: task, timeout: timeout)
        } else if isSyncing, let inFlightSync {
            // A sync from another trigger (e.g. a foreground re-entry) is already running —
            // wait for that one instead of starting a second, redundant sync.
            await Self.wait(for: inFlightSync, timeout: timeout)
        }
        return await hasRequiredData()
    }

    @discardableResult
    private func attemptSync(bypassThrottle: Bool) -> Task<Void, Never>? {
        guard !isUITesting, !isSyncing, isOnline() else { return nil }
        if !bypassThrottle, let lastSyncStartedAt, now().timeIntervalSince(lastSyncStartedAt) < Self.throttleInterval {
            return nil
        }

        isSyncing = true
        lastSyncStartedAt = now()
        status = .syncing

        let task = Task { [weak self] in
            guard let self else { return }
            let report = await service.sync()
            await MainActor.run {
                self.handle(report: report)
            }
        }
        inFlightSync = task
        return task
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

    /// Waits for `task` to finish, or for `timeout` seconds to elapse — whichever comes first.
    /// `task` itself is not forcibly stopped if the timeout wins the race (there is no
    /// cooperative cancellation point mid network-request today), but the caller stops waiting
    /// and re-checks actual on-device state instead of blocking indefinitely.
    private static func wait(for task: Task<Void, Never>, timeout: TimeInterval) async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await task.value }
            group.addTask { try? await Task.sleep(nanoseconds: UInt64(max(timeout, 0) * 1_000_000_000)) }
            await group.next()
            group.cancelAll()
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
