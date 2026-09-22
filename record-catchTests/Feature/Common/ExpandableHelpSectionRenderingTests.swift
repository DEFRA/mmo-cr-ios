import XCTest
import SwiftUI
@testable import record_catch

/// Hosts `ExpandableHelpSection` behind local `@State` so its disclosure toggle actually runs,
/// exercising both the collapsed and expanded `body` branches — including the
/// `.frame(minWidth:minHeight:)`/`.contentShape` tap-target fix on the disclosure button
/// (mirroring `LinkButton`/`AppLockView`/`RadioOption`/`CheckboxOption`) and the optional
/// `accessibilityIdentifier` modifier's both branches. See `ViewRenderingHarness` and ADR-0016 §5.
private struct ExpandableHelpSectionHost: View {
    let accessibilityIdentifier: String?

    init(accessibilityIdentifier: String? = nil) {
        self.accessibilityIdentifier = accessibilityIdentifier
    }

    var body: some View {
        ExpandableHelpSection(title: "Understanding catch record statuses", accessibilityIdentifier: accessibilityIdentifier) {
            HelpItemsList(items: [
                HelpItem(heading: "Unsent:", description: "Saved on your device and not yet submitted.")
            ])
        }
    }
}

@MainActor
final class ExpandableHelpSectionRenderingTests: XCTestCase {

    func test_render_collapsed_noAccessibilityIdentifier() {
        ViewRenderingHarness.render(ExpandableHelpSectionHost())
    }

    func test_render_collapsed_withAccessibilityIdentifier() {
        ViewRenderingHarness.render(
            ExpandableHelpSectionHost(accessibilityIdentifier: "statusHelpSection")
        )
    }

    func test_render_itemsInitializer_rendersHelpItemsList() {
        ViewRenderingHarness.render(
            ExpandableHelpSection(
                title: "Understanding catch record statuses",
                items: [
                    HelpItem(heading: "Unsent:", description: "Saved on your device and not yet submitted."),
                    HelpItem(heading: "Submitted:", description: "Received by the MMO.")
                ]
            )
        )
    }
}
