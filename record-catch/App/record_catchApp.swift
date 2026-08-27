//
//  record_catchApp.swift
//  record-catch
//
//  Created by Paul Halpin on 08/07/2026.
//

import SwiftUI
import SwiftData

@main
struct record_catchApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    let environment = AppEnvironment()
    @State private var languageStore = AppLanguageStore()
    @State private var tabRouter = AppTabRouter(selection: Self.seedTabSelection)

    // Local session / offline biometric re-entry (ADR-0009): a device-local "session" persists
    // across relaunches so the app can offer sign-in / app-lock / home without a backend session
    // (no real authentication exists yet). All of that composition-root wiring and decision logic
    // lives in `RootSessionCoordinator`, which is unit-tested in its own right.
    @State private var sessionCoordinator = RootSessionCoordinator.make()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            rootView
                .environment(environment)
                .environment(languageStore)
                .environment(tabRouter)
                .environment(\.locale, languageStore.language.locale)
                // The design system (`AppColors`) mirrors the GOV.UK Design System, which is
                // light-only: every colour (backgrounds, borders, text) is a fixed literal
                // rather than a Dark Mode-adaptive one. Without forcing `.light` here, controls
                // that don't set an explicit foreground (e.g. `TextField`/`SecureField` typed
                // text) fall back to the system's dynamic label colour, which renders white on
                // the app's hardcoded white field backgrounds in Dark Mode — making entered text
                // invisible. Forcing light appearance keeps the whole app consistent until/unless
                // a Dark Mode variant of the design system is designed and an ADR records it.
                .preferredColorScheme(.light)
                .onChange(of: scenePhase) { oldPhase, newPhase in
                    // Re-lock on return to foreground after backgrounding (ADR-0009 §4). Only
                    // relevant once the user has actually reached Home this launch.
                    guard newPhase == .active, oldPhase == .background, sessionCoordinator.phase == .home else { return }
                    sessionCoordinator.refreshPhase()
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

    /// The real app root: sign-in / app-lock / home, per `sessionCoordinator.phase`. Wrapped in
    /// `UITestRootView`, which substitutes a UI-test-seeded screen instead when a recognised
    /// `-uiTest*` launch argument is present.
    @ViewBuilder
    private var rootView: some View {
        UITestRootView {
            switch sessionCoordinator.phase {
            case .home:
                RootTabView()
            case .appLock:
                AppLockView(
                    viewModel: sessionCoordinator.makeAppLockViewModel(
                        unlockReason: languageStore.localized("appLock.unlockReason")
                    )
                )
            case .signIn:
                SignInView(onSignIn: sessionCoordinator.handleSignIn)
            }
        }
    }
}
