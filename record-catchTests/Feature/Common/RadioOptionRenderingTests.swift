import XCTest
import SwiftUI
@testable import record_catch

/// Renders `RadioOption` in both selection states so its `body` — including the
/// `isSelected` glyph branch and the `.frame(minWidth:minHeight:)`/`.contentShape` tap-target
/// fix (mirroring `LinkButton`/`AppLockView`) — actually executes under test. See
/// `ViewRenderingHarness` and ADR-0016 §5.
@MainActor
final class RadioOptionRenderingTests: XCTestCase {

    func test_render_unselected() {
        ViewRenderingHarness.render(
            RadioOption(title: "No", isSelected: false) {}
        )
    }

    func test_render_selected() {
        ViewRenderingHarness.render(
            RadioOption(title: "Yes", isSelected: true) {}
        )
    }

    func test_action_isInvokedOnTap() {
        var didInvokeAction = false
        let option = RadioOption(title: "Yes", isSelected: false) {
            didInvokeAction = true
        }

        option.action()

        XCTAssertTrue(didInvokeAction)
    }
}
