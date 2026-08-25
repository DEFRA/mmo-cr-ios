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
    /// DEMO-ONLY BYPASS: no real authentication exists yet, so tapping "Sign in"
    /// always succeeds regardless of form input. Once real auth lands this should
    /// be driven by an authenticated-session check instead of local UI state.
    @State private var isSignedIn = false

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
        }
        .modelContainer(sharedModelContainer)
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
        } else if isSignedIn {
            RootTabView()
        } else {
            SignInView(onSignIn: { isSignedIn = true })
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
        draft.gear = GearOption.seineNets.withMeasurements([
            GearMeasurement(id: "meshSize", labelKey: "catchRecord.gear.measurement.meshSize", value: 80)
        ])
        draft.speciesCaught = [SpeciesOption(name: "Atlantic cod (COD)").withWeights(above: "250", below: nil, discarded: nil)]
        draft.speciesNotLanded = [SpeciesOption(name: "Atlantic cod (COD)").withWeights(above: "5", below: nil, discarded: nil)]
        return draft
    }
}
