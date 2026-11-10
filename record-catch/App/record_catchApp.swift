//
//  record_catchApp.swift
//  record-catch
//
//  Created by Paul Halpin on 08/07/2026.
//

import SwiftUI
import SwiftData

@main
struct RecordCatchApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            CatchRecordEntity.self,
            FavouriteEntity.self,
            ReferenceItemEntity.self,
            ReferenceDatasetStateEntity.self,
            ReferenceBlobEntity.self
        ])
        // Protects on-device catch-record data at rest (vessel, dates, ports, gear, species — see
        // ADR-0014, DEFRA data-at-rest requirement): the store is only accessible after the user
        // has unlocked the device at least once since boot, and is never included in an unencrypted
        // iTunes/Finder backup of a locked device.
        //
        // In-memory-only for any `-uiTest*` launch (see `LaunchArguments.isUITesting`), so drafts
        // saved by one UI test never persist into another test's launch of the app within the same
        // simulator/test-run — otherwise Home's drafts + records pagination (and any other screen
        // reading persisted drafts) would accumulate state across tests, making exact assertions
        // non-deterministic.
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: LaunchArguments.current.isUITesting,
            cloudKitDatabase: .none
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    let environment = AppEnvironment()
    @State private var languageStore = AppLanguageStore()
    @State private var tabRouter = AppTabRouter(selection: Self.seedTabSelection)

    // Connectivity monitoring (ADR-0019): a single app-wide signal behind the
    // `ConnectivityMonitoring` seam, injected via `\.connectivityMonitor` (not `.environment(_:)`)
    // because the real and `-uiTestOffline` stub are different concrete types.
    @State private var connectivityMonitor: any ConnectivityMonitoring

    // Local session / offline biometric re-entry (ADR-0009), now backed by real Entra
    // authentication with a 7-day offline grace period (ADR-0022). All of that composition-root
    // wiring and decision logic lives in `RootSessionCoordinator`, which is unit-tested in its own
    // right. Built in `init()` (not a `@State` default expression) so it can share the *same*
    // `connectivityMonitor` instance constructed just above, rather than standing up a second
    // `NWPathMonitor`.
    @State private var sessionCoordinator: RootSessionCoordinator
    @Environment(\.scenePhase) private var scenePhase

    // Reference-data background sync (ADR-0024): owns *when* ports/species/gears/vessels refresh
    // from the API and the UI-facing status `SyncErrorBanner` renders. Shares this launch's
    // `connectivityMonitor` instance (see the comment on `connectivityMonitor` above) rather than
    // constructing a second one.
    @State private var referenceDataSyncCoordinator: ReferenceDataSyncCoordinator

    init() {
        let monitor = Self.makeConnectivityMonitor()
        _connectivityMonitor = State(initialValue: monitor)
        _sessionCoordinator = State(initialValue: RootSessionCoordinator.make(connectivityMonitor: monitor))

        // Bootstraps `ReferenceDataStoreProvider.shared` (used by the cached reference-data search
        // providers elsewhere in the app) before anything can read it — see that type's doc
        // comment for the "set once in init(), read many times" contract this relies on.
        ReferenceDataStoreProvider.bootstrap(modelContainer: sharedModelContainer)
        _referenceDataSyncCoordinator = State(initialValue: ReferenceDataSyncCoordinator.make(
            store: ReferenceDataStore(modelContainer: sharedModelContainer),
            connectivityMonitor: monitor
        ))
    }

    var body: some Scene {
        WindowGroup {
            rootView
                .environment(environment)
                .environment(languageStore)
                .environment(tabRouter)
                .environment(\.locale, languageStore.language.locale)
                .environment(\.connectivityMonitor, connectivityMonitor)
                .environment(\.referenceDataSyncStatus, referenceDataSyncCoordinator)
                // The design system (`AppColors`) mirrors the GOV.UK Design System, which is
                // light-only: every colour (backgrounds, borders, text) is a fixed literal
                // rather than a Dark Mode-adaptive one. Without forcing `.light` here, controls
                // that don't set an explicit foreground (e.g. `TextField`/`SecureField` typed
                // text) fall back to the system's dynamic label colour, which renders white on
                // the app's hardcoded white field backgrounds in Dark Mode — making entered text
                // invisible. Forcing light appearance keeps the whole app consistent until/unless
                // a Dark Mode variant of the design system is designed and an ADR records it.
                .preferredColorScheme(.light)
                .task {
                    // Silent session check at launch (ADR-0022 §5) — never blocks the UI; a
                    // no-op unless a local session already exists (and skipped entirely for
                    // `-uiTest*` launches, see `RootSessionCoordinator.skipsBackgroundVerification`).
                    await sessionCoordinator.verifySessionInBackground()
                }
                .onChange(of: scenePhase) { oldPhase, newPhase in
                    // Re-check on return to foreground after backgrounding (ADR-0009 §4 /
                    // ADR-0022 §5). Not relevant from the sign-in screen itself — there is
                    // nothing to re-verify or re-lock yet.
                    guard newPhase == .active, oldPhase == .background, sessionCoordinator.phase != .signIn else { return }
                    sessionCoordinator.refreshPhase()
                }
                .onChange(of: scenePhase) { oldPhase, newPhase in
                    // Reference-data foreground trigger (ADR-0024 "Triggers") — independent of the
                    // session re-check above, since a sync attempt is appropriate even while
                    // staying signed in to the app-lock/home phases.
                    guard newPhase == .active, oldPhase == .background else { return }
                    referenceDataSyncCoordinator.notifyForeground()
                }
                .onChange(of: connectivityMonitor.isOnline) { wasOnline, isOnline in
                    guard isOnline, !wasOnline else { return }
                    referenceDataSyncCoordinator.notifyConnectivityRestored()
                }
        }
        .modelContainer(sharedModelContainer)
    }

    /// Seeds `AppTabRouter.selection` synchronously from a UI-test launch argument, before the
    /// first `body` evaluation — mirroring how `CatchRecordRouter`'s `path` is seeded via
    /// `initialRoute` (see ADR-0006).
    private static var seedTabSelection: AppTab {
        let launchArguments = LaunchArguments.current
        if launchArguments.contains(.settings) || launchArguments.contains(.manageAccount) {
            return .settings
        } else if launchArguments.contains(.notifications) {
            return .notifications
        }
        return .home
    }

    /// Builds the app-wide `ConnectivityMonitoring` instance. Substitutes a fixed-offline
    /// `StubConnectivityMonitor` under the `-uiTestOffline` seam (see `LaunchArguments`) so
    /// XCUITest can assert the banner deterministically, without depending on Airplane Mode or
    /// simulator network conditioning. Otherwise returns a live `NetworkConnectivityMonitor`,
    /// already `start()`-ed so observation begins as early as possible.
    private static func makeConnectivityMonitor() -> any ConnectivityMonitoring {
        guard !LaunchArguments.current.contains(.offline) else {
            return StubConnectivityMonitor(isOnline: false)
        }
        let monitor = NetworkConnectivityMonitor()
        monitor.start()
        return monitor
    }

    /// The real app root: sign-in / app-lock / home, per `sessionCoordinator.phase`. Wrapped in
    /// `UITestRootView`, which substitutes a UI-test-seeded screen instead when a recognised
    /// `-uiTest*` launch argument is present.
    @ViewBuilder
    private var rootView: some View {
        UITestRootView {
            switch sessionCoordinator.phase {
            case .home:
                RootTabView(onSignOut: {
                    sessionCoordinator.handleSignOut()
                    // Reference data itself is kept (see ADR-0024 "Sign-out"), but throttle/
                    // in-flight state must not leak into the next session.
                    referenceDataSyncCoordinator.resetForSignOut()
                })
            case .preparingData:
                // Blocks Home behind a successful reference-data sync (ADR-0024 "Data before
                // Home") — no picker is reachable until ports/species/gears are present.
                DataPreparationView(
                    viewModel: DataPreparationViewModel(
                        coordinator: referenceDataSyncCoordinator,
                        onReady: sessionCoordinator.completeDataPreparation,
                        onSignOut: {
                            sessionCoordinator.handleSignOut()
                            referenceDataSyncCoordinator.resetForSignOut()
                        }
                    )
                )
            case .appLock:
                AppLockView(
                    viewModel: sessionCoordinator.makeAppLockViewModel(
                        unlockReason: languageStore.localized("appLock.unlockReason")
                    )
                )
            case .signIn:
                sessionCoordinator.makeSignInView()
            }
        }
    }
}
