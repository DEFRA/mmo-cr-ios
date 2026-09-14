import XCTest
import SwiftUI
@testable import record_catch

/// `UITestRootView.body` only *constructs* the seeded screen (`CatchRecordHostView`/
/// `RootTabView`) for a given `-uiTest*` launch argument — it does not render it — so exercising
/// every branch here is a safe, hermetic way to cover the routing/seeding logic (including the
/// `seed*` helpers) without a UI test or a hosting environment. No `@Environment` values are read
/// by `UITestRootView` itself, so this cannot crash the way rendering a deeper view's own body
/// (which reads `@Environment(AppLanguageStore.self)`, etc.) would outside a real view hierarchy.
@MainActor
final class UITestRootViewTests: XCTestCase {

    private func exerciseBody(for flag: LaunchArguments.Flag) {
        let sut = UITestRootView(launchArguments: LaunchArguments(raw: [flag.rawValue])) {
            Text("production root")
        }
        _ = sut.body
    }

    func test_everyRecognisedLaunchArgument_seedsAScreenWithoutCrashing() {
        for flag in [
            LaunchArguments.Flag.catchRecordDraft,
            .catchRecordNew,
            .catchRecordAddPort,
            .catchRecordConfirmSamePort,
            .catchRecordSelectPort,
            .catchRecordSelectGear,
            .catchRecordCheckYourAnswers,
            .catchRecordRecordSpeciesWeights,
            .catchRecordRemoveSpecies,
            .catchRecordSubmissionConfirmation,
            .catchRecordSubmissionSuccess,
            .home,
            .settings,
            .manageAccount,
            .notifications,
            .tabBar
        ] {
            exerciseBody(for: flag)
        }
    }

    func test_noRecognisedLaunchArgument_fallsBackToProductionRoot() {
        var productionRootBuilt = false
        let sut = UITestRootView(launchArguments: LaunchArguments(raw: [])) {
            productionRootBuilt = true
            return Text("production root")
        }

        _ = sut.body

        XCTAssertTrue(productionRootBuilt)
    }
}
