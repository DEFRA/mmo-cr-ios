//
//  UITestRootView.swift
//  record-catch
//
//  Hosts the app root's UI-test-only launch-argument seams, kept out of `record_catchApp` so the
//  production entry point isn't dominated by test scaffolding.
//
//  Default app root stays whatever `productionRoot` builds (sign-in / app-lock / home). UI-test
//  launch arguments show the Home / Create-a-catch-record journey instead, for lightweight
//  UI-test hosting: `-uiTestHome` boots the root `TabView` at Home (see ADR-0006);
//  `-uiTestCatchRecordNew` seeds the journey's own stack at Select vessel (as if "Create a new
//  catch record" was tapped) hosted as a BARE `CatchRecordHostView` with no tab bar at all, so the
//  existing `CatchRecordUITests` continue to exercise the journey in isolation and do not regress;
//  `-uiTestCatchRecordDraft` seeds the stack at Draft action for a stubbed unsent record.
//  `-uiTestManageAccount` boots the root `TabView` on Settings with its own stack seeded straight
//  to "Manage your account" (see ADR-0007).
//

import SwiftUI

/// Wraps the app's real root view, substituting a UI-test-seeded screen when a recognised
/// `-uiTest*` launch argument is present.
struct UITestRootView<ProductionRoot: View>: View {
    private let launchArguments: LaunchArguments
    private let productionRoot: () -> ProductionRoot

    init(
        launchArguments: LaunchArguments = .current,
        @ViewBuilder productionRoot: @escaping () -> ProductionRoot
    ) {
        self.launchArguments = launchArguments
        self.productionRoot = productionRoot
    }

    var body: some View {
        if launchArguments.contains(.catchRecordDraft) {
            CatchRecordHostView(initialRoute: .draftAction(Self.seedDraftRow))
        } else if launchArguments.contains(.catchRecordNew) {
            CatchRecordHostView(initialRoute: .selectVessel)
        } else if launchArguments.contains(.catchRecordAddPort) {
            // No favourites yet → Add-port screen first.
            CatchRecordHostView(
                initialRoute: .addPort(vessel: "ACHILLES", referenceNumber: "A1234520260727150815", returnPhase: nil),
                favouritePorts: StubFavouritePortsProvider()
            )
        } else if launchArguments.contains(.catchRecordConfirmSamePort) {
            // Seeds straight to the "Was <port> your departure and return port?" confirmation
            // screen, for UI testing its Yes/No branching without driving the search flow by hand.
            CatchRecordHostView(
                initialRoute: .confirmSamePort(
                    vessel: "ACHILLES",
                    referenceNumber: "A1234520260727150815",
                    port: PortOption(name: "Hastings")
                ),
                favouritePorts: StubFavouritePortsProvider()
            )
        } else if launchArguments.contains(.catchRecordSelectPort) {
            // Seeded favourites → Select-departure-port screen first.
            CatchRecordHostView(
                initialRoute: .selectPort(phase: .departure, vessel: "ACHILLES", referenceNumber: "A1234520260727150815"),
                favouritePorts: StubFavouritePortsProvider(initialFavourites: [PortOption(name: "Hastings")])
            )
        } else if launchArguments.contains(.catchRecordSelectGear) {
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
        } else if launchArguments.contains(.catchRecordCheckYourAnswers) {
            // Fully-populated draft → Check your answers screen, for UI testing the summary/Change
            // links without driving the whole journey by hand.
            CatchRecordHostView(
                initialRoute: .checkYourAnswers(referenceNumber: "A1234520260727150815"),
                draft: Self.seedCheckYourAnswersDraft
            )
        } else if launchArguments.contains(.catchRecordSubmissionConfirmation) {
            // Seeds straight to the final Confirmation screen, for UI testing the checkbox
            // validation and Accept action without driving the whole journey by hand.
            CatchRecordHostView(initialRoute: .submissionConfirmation(referenceNumber: "A1234520260727150815"))
        } else if launchArguments.contains(.catchRecordSubmissionSuccess) {
            // Seeds straight to the final "Submitted" screen, for UI testing the confirmation
            // panel and "View your catch records" action without driving the whole journey by hand.
            CatchRecordHostView(initialRoute: .submissionSuccess(referenceNumber: "A1234520260727150815"))
        } else if launchArguments.contains(.home) {
            RootTabView()
        } else if launchArguments.contains(.settings) {
            RootTabView()
        } else if launchArguments.contains(.manageAccount) {
            // Seeds the Settings tab's own stack straight to "Manage your account" (see
            // ADR-0007), for UI testing that screen without driving Settings → My account by hand.
            RootTabView(initialSettingsRoute: .manageAccount)
        } else if launchArguments.contains(.notifications) {
            RootTabView()
        } else if launchArguments.contains(.tabBar) {
            RootTabView()
        } else {
            productionRoot()
        }
    }

    /// Stubbed unsent record used to seed `-uiTestCatchRecordDraft`.
    private static var seedDraftRow: SubmissionRow {
        SubmissionRow(dateText: "20 Nov 2020", vesselName: "ACHILLES", status: .unsent, createdBy: "J.Smith")
    }

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
        let gear = GearOption.seineNets
            .withRequiredMeasurements([
                GearMeasurement(id: "meshSize", labelKey: "catchRecord.gear.measurement.meshSize", value: 80)
            ])
            .withVariableMeasurements([
                GearMeasurement(id: "timesShot", labelKey: "catchRecord.gear.variableMeasurement.timesShot", value: 5)
            ])
        draft.gearCatches = [
            GearCatch(
                gear: gear,
                statisticalArea: "27.7.e",
                speciesCaught: [SpeciesOption(name: "Atlantic cod (COD)").withWeights(above: "250", below: nil, discarded: nil)]
            )
        ]
        draft.speciesNotLanded = [SpeciesOption(name: "Atlantic cod (COD)").withWeights(above: "5", below: nil, discarded: nil)]
        return draft
    }
}
