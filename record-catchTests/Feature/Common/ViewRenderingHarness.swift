import XCTest
import SwiftUI
@testable import record_catch

/// Renders real SwiftUI views inside a hosted window so their `body` (and the state changes it
/// depends on) actually execute, rather than only unit-testing their extracted pure logic. This
/// complements (does not replace) the pure-function tests already covering
/// `DateEntryField.parsedDate`, `TextInputField.shouldShowRequiredError`,
/// `SearchDropdownField.filteredOptions`, etc.
///
/// Mirrors ADR-0016 §5's direction (a preview-driven rendering approach to the structural
/// SwiftUI-`body` coverage gap) for the small set of shared "Common/Components/Form" views this
/// change added or extended, rather than adding them to `sonar.coverage.exclusions` — these views
/// carry real conditional/accessibility logic (error visibility, focus, identifiers), which ADR-
/// 0016 §4 explicitly says must stay counted, not be excluded.
@MainActor
enum ViewRenderingHarness {
    /// Hosts `view` in an offscreen key window and forces a layout pass, so SwiftUI evaluates its
    /// `body` (and any `.onAppear`/`.onChange` side effects) the same way a real screen would.
    static func render(_ view: some View) {
        let host = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 400, height: 900))
        window.rootViewController = host
        window.isHidden = false
        window.makeKeyAndVisible()
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        // Let any `.onAppear`/`.task`-scheduled work (e.g. `ErrorSummary`'s focus-on-appear) run.
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
    }
}
