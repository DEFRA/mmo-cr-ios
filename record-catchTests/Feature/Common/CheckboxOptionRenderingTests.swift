import XCTest
import SwiftUI
@testable import record_catch

/// Renders `CheckboxOption` across its selection and subtitle states so its `body` — including
/// the `isSelected` tick-glyph branch, the optional `subtitle` branch, and the
/// `.frame(minWidth:minHeight:)`/`.contentShape` tap-target fix (mirroring `LinkButton`/
/// `AppLockView`) — actually executes under test. See `ViewRenderingHarness` and ADR-0016 §5.
@MainActor
final class CheckboxOptionRenderingTests: XCTestCase {

    func test_render_unselected_noSubtitle() {
        ViewRenderingHarness.render(
            CheckboxOption(title: "Bottom trawl", isSelected: false) {}
        )
    }

    func test_render_selected_withSubtitle() {
        ViewRenderingHarness.render(
            CheckboxOption(title: "Seine nets (not specified)", subtitle: "100mm mesh", isSelected: true) {}
        )
    }

    func test_action_isInvokedOnTap() {
        var didInvokeAction = false
        let option = CheckboxOption(title: "Bottom trawl", isSelected: false) {
            didInvokeAction = true
        }

        option.action()

        XCTAssertTrue(didInvokeAction)
    }
}
