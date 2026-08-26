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

    // MARK: - Local session / offline biometric re-entry (ADR-0009)
    //
    // `isSignedIn` is gone: a device-local "session" now persists across relaunches via
    // `localSessionStore` (Keychain-backed, NOT a backend session — no real authentication
    // exists yet). `rootPhase` decides which of sign-in / app-lock / home to show, computed via
    // the pure `BiometricReentryPolicy` helper so the logic is unit-tested, not duplicated here.
    private let biometricAuthenticator: BiometricAuthenticating
    private let localSessionStore: LocalSessionStoring
    private let reentrySecretStore: ReentrySecretStoring
    private let biometricPreferenceStore: BiometricPreferenceStoring

    @State private var rootPhase: RootPhase
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let arguments = ProcessInfo.processInfo.arguments

        // Deterministic starting point for Settings/Manage-account UI tests (mirrors
        // `-uiTestResetLanguage`): the real `UserDefaultsBiometricPreferenceStore` persists
        // across launches, and the toggle's "on" path now requires a real (simulator-absent)
        // biometric check, so tests need a known "off" starting value.
        if arguments.contains("-uiTestManageAccount") || arguments.contains("-uiTestSettings") {
            UserDefaults.standard.removeObject(forKey: UserDefaultsBiometricPreferenceStore.storageKey)
        }

        let biometricAuthenticator: BiometricAuthenticating
        let localSessionStore: LocalSessionStoring
        let reentrySecretStore: ReentrySecretStoring
        let biometricPreferenceStore: BiometricPreferenceStoring

        // UI-test seams (ADR-0009): inject deterministic fakes so app-lock states can be driven
        // without real biometric hardware, mirroring the existing `-uiTest*` launch-arg pattern.
        if arguments.contains("-uiTestAppLockLocked") {
            biometricAuthenticator = FakeBiometricAuthenticator(availability: .available(.faceID))
            localSessionStore = InMemoryLocalSessionStore(hasSession: true)
            reentrySecretStore = InMemoryReentrySecretStore(exists: true)
            biometricPreferenceStore = InMemoryBiometricPreferenceStore(initialValue: true)
        } else if arguments.contains("-uiTestAppLockFallback") {
            biometricAuthenticator = FakeBiometricAuthenticator(availability: .unavailable(.noBiometryEnrolled))
            localSessionStore = InMemoryLocalSessionStore(hasSession: true)
            reentrySecretStore = InMemoryReentrySecretStore(exists: false)
            biometricPreferenceStore = InMemoryBiometricPreferenceStore(initialValue: false)
        } else {
            biometricAuthenticator = LABiometricAuthenticator()
            localSessionStore = KeychainLocalSessionStore()
            reentrySecretStore = KeychainReentrySecretStore()
            biometricPreferenceStore = UserDefaultsBiometricPreferenceStore()
        }

        self.biometricAuthenticator = biometricAuthenticator
        self.localSessionStore = localSessionStore
        self.reentrySecretStore = reentrySecretStore
        self.biometricPreferenceStore = biometricPreferenceStore
        _rootPhase = State(initialValue: Self.computeRootPhase(
            biometricAuthenticator: biometricAuthenticator,
            localSessionStore: localSessionStore,
            reentrySecretStore: reentrySecretStore,
            biometricPreferenceStore: biometricPreferenceStore
        ))
    }

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
                    guard newPhase == .active, oldPhase == .background, rootPhase == .home else { return }
                    rootPhase = Self.computeRootPhase(
                        biometricAuthenticator: biometricAuthenticator,
                        localSessionStore: localSessionStore,
                        reentrySecretStore: reentrySecretStore,
                        biometricPreferenceStore: biometricPreferenceStore
                    )
                }
        }
        .modelContainer(sharedModelContainer)
    }

    /// Root-flow phase: which of sign-in / app-lock / home to show (ADR-0009).
    private enum RootPhase: Equatable {
        case signIn
        case appLock
        case home
    }

    /// Pure-computed (given the injected stores) root phase, via `BiometricReentryPolicy`.
    private static func computeRootPhase(
        biometricAuthenticator: BiometricAuthenticating,
        localSessionStore: LocalSessionStoring,
        reentrySecretStore: ReentrySecretStoring,
        biometricPreferenceStore: BiometricPreferenceStoring
    ) -> RootPhase {
        guard localSessionStore.hasLocalSession() else { return .signIn }
        let offer = BiometricReentryPolicy.offer(
            hasLocalSession: true,
            preferenceEnabled: biometricPreferenceStore.isFaceIDEnabled(),
            availability: biometricAuthenticator.biometricAvailability(),
            secretExists: reentrySecretStore.secretExists()
        )
        switch offer {
        case .offer: return .appLock
        case .fallToSignIn: return .signIn
        }
    }

    /// Runs after the (currently stubbed) sign-in succeeds: begins the local session and,
    /// if the user has previously opted in to Face ID re-entry, re-provisions the secret
    /// defensively (idempotent — a no-op if one is already provisioned).
    private func handleSignIn() {
        try? localSessionStore.beginSession()
        if biometricPreferenceStore.isFaceIDEnabled() {
            try? reentrySecretStore.provisionSecret()
        }
        rootPhase = .home
    }

    /// Builds a fully-configured `AppLockViewModel` for the app-lock branch of `rootView`.
    /// Kept as a plain (non-`@ViewBuilder`) method so the callback assignments below are
    /// ordinary statements, not misread as view content by the `@ViewBuilder` DSL.
    private func makeAppLockViewModel() -> AppLockViewModel {
        let viewModel = AppLockViewModel(
            biometricAuthenticator: biometricAuthenticator,
            sessionStore: localSessionStore,
            secretStore: reentrySecretStore,
            preferenceStore: biometricPreferenceStore,
            unlockReason: languageStore.localized("appLock.unlockReason")
        )
        viewModel.onUnlocked = { rootPhase = .home }
        viewModel.onFallbackToSignIn = { rootPhase = .signIn }
        return viewModel
    }

    /// Seeds `AppTabRouter.selection` synchronously from a UI-test launch argument, before the
    /// first `body` evaluation — mirroring how `CatchRecordRouter`'s `path` is seeded via
    /// `initialRoute` (see ADR-0006).
    private static var seedTabSelection: AppTab {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-uiTestSettings") || arguments.contains("-uiTestManageAccount") {
            return .settings
        } else if arguments.contains("-uiTestNotifications") {
            return .notifications
        }
        return .home
    }

    // Default app root stays `SignInView`. UI-test launch arguments show the Home /
    // Create-a-catch-record journey instead, for lightweight UI-test hosting:
    // `-uiTestHome` boots the root `TabView` at Home (see ADR-0006); `-uiTestCatchRecordNew`
    // seeds the journey's own stack at Select vessel (as if "Create a new catch record" was
    // tapped) hosted as a BARE `CatchRecordHostView` with no tab bar at all, so the existing
    // `CatchRecordUITests` continue to exercise the journey in isolation and do not regress;
    // `-uiTestCatchRecordDraft` seeds the stack at Draft action for a stubbed unsent record.
    // `-uiTestManageAccount` boots the root `TabView` on Settings with its own stack seeded
    // straight to "Manage your account" (see ADR-0007).
    @ViewBuilder
    private var rootView: some View {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-uiTestCatchRecordDraft") {
            CatchRecordHostView(initialRoute: .draftAction(Self.seedDraftRow))
        } else if arguments.contains("-uiTestCatchRecordNew") {
            CatchRecordHostView(initialRoute: .selectVessel)
        } else if arguments.contains("-uiTestCatchRecordAddPort") {
            // No favourites yet → Add-port screen first.
            CatchRecordHostView(
                initialRoute: .addPort(vessel: "ACHILLES", referenceNumber: "A1234520260727150815", returnPhase: nil),
                favouritePorts: StubFavouritePortsProvider()
            )
        } else if arguments.contains("-uiTestCatchRecordSelectPort") {
            // Seeded favourites → Select-departure-port screen first.
            CatchRecordHostView(
                initialRoute: .selectPort(phase: .departure, vessel: "ACHILLES", referenceNumber: "A1234520260727150815"),
                favouritePorts: StubFavouritePortsProvider(initialFavourites: [PortOption(name: "Hastings")])
            )
        } else if arguments.contains("-uiTestCatchRecordSelectGear") {
            // Seeded favourite gear → "What gear did you use?" screen first, for UI testing the
            // per-trip variable-measurement conditional reveal and its validation.
            CatchRecordHostView(
                initialRoute: .selectGear(vessel: "ACHILLES", referenceNumber: "A1234520260727150815"),
                favouriteGears: StubFavouriteGearProvider(initialFavourites: [
                    GearOption.seineNets.withRequiredMeasurements([
                        GearMeasurement(id: "meshSize", labelKey: "catchRecord.gear.measurement.meshSize", value: 100)
                    ])
                ])
            )
        } else if arguments.contains("-uiTestCatchRecordCheckYourAnswers") {
            // Fully-populated draft → Check your answers screen, for UI testing the summary/Change
            // links without driving the whole journey by hand.
            CatchRecordHostView(
                initialRoute: .checkYourAnswers(referenceNumber: "A1234520260727150815"),
                draft: Self.seedCheckYourAnswersDraft
            )
        } else if arguments.contains("-uiTestCatchRecordSubmissionConfirmation") {
            // Seeds straight to the final Confirmation screen, for UI testing the checkbox
            // validation and Accept action without driving the whole journey by hand.
            CatchRecordHostView(
                initialRoute: .submissionConfirmation(referenceNumber: "A1234520260727150815")
            )
        } else if arguments.contains("-uiTestCatchRecordSubmissionSuccess") {
            // Seeds straight to the final "Submitted" screen, for UI testing the confirmation
            // panel and "View your catch records" action without driving the whole journey by hand.
            CatchRecordHostView(
                initialRoute: .submissionSuccess(referenceNumber: "A1234520260727150815")
            )
        } else if arguments.contains("-uiTestHome") {
            RootTabView()
        } else if arguments.contains("-uiTestSettings") {
            RootTabView()
        } else if arguments.contains("-uiTestManageAccount") {
            // Seeds the Settings tab's own stack straight to "Manage your account" (see
            // ADR-0007), for UI testing that screen without driving Settings → My account by hand.
            RootTabView(initialSettingsRoute: .manageAccount)
        } else if arguments.contains("-uiTestNotifications") {
            RootTabView()
        } else if arguments.contains("-uiTestTabBar") {
            RootTabView()
        } else {
            switch rootPhase {
            case .home:
                RootTabView()
            case .appLock:
                AppLockView(viewModel: makeAppLockViewModel())
            case .signIn:
                SignInView(onSignIn: handleSignIn)
            }
        }
    }

    /// Stubbed unsent record used to seed `-uiTestCatchRecordDraft`.
    private static let seedDraftRow = SubmissionRow(
        dateText: "20 Nov 2020",
        vesselName: "ACHILLES",
        status: .unsent,
        createdBy: "J.Smith"
    )

    /// Fully-populated `CatchRecordDraft` used to seed `-uiTestCatchRecordCheckYourAnswers`, so the
    /// Check-your-answers screen can be UI-tested (headings, rows, Change navigation) without
    /// driving the whole journey by hand.
    @MainActor
    private static var seedCheckYourAnswersDraft: CatchRecordDraft {
        let draft = CatchRecordDraft()
        draft.vessel = "ACHILLES"
        draft.departureDate = Date(timeIntervalSince1970: 1_785_000_000)
        draft.returnDate = Date(timeIntervalSince1970: 1_785_100_000)
        draft.departurePort = PortOption(name: "Plymouth")
        draft.returnPort = PortOption(name: "Plymouth")
        draft.statisticalArea = "27.7.e"
        draft.gear = GearOption.seineNets
            .withRequiredMeasurements([
                GearMeasurement(id: "meshSize", labelKey: "catchRecord.gear.measurement.meshSize", value: 80)
            ])
            .withVariableMeasurements([
                GearMeasurement(id: "timesShot", labelKey: "catchRecord.gear.variableMeasurement.timesShot", value: 5)
            ])
        draft.speciesCaught = [SpeciesOption(name: "Atlantic cod (COD)").withWeights(above: "250", below: nil, discarded: nil)]
        draft.speciesNotLanded = [SpeciesOption(name: "Atlantic cod (COD)").withWeights(above: "5", below: nil, discarded: nil)]
        return draft
    }
}
