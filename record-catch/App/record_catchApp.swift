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
            Item.self,
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

    var body: some Scene {
        WindowGroup {
            rootView
                .environment(environment)
                .environment(languageStore)
                .environment(\.locale, languageStore.language.locale)
        }
        .modelContainer(sharedModelContainer)
    }

    // Default app root stays `SignInView`. UI-test launch arguments show the Home /
    // Create-a-catch-record journey instead, for lightweight UI-test hosting:
    // `-uiTestHome` boots at Home; `-uiTestCatchRecordNew` seeds the stack at Select
    // vessel (as if "Create a new catch record" was tapped); `-uiTestCatchRecordDraft`
    // seeds the stack at Draft action for a stubbed unsent record.
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
        } else if arguments.contains("-uiTestHome") {
            CatchRecordHostView()
        } else {
            SignInView()
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
