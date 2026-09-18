import XCTest
import SwiftUI
@testable import record_catch

@MainActor
final class InlineErrorTextRenderingTests: XCTestCase {

    func test_render_withAccessibilityIdentifier() {
        ViewRenderingHarness.render(
            InlineErrorText(message: "Select a port from the list", accessibilityIdentifier: "Test.error")
                .environment(record_catch.AppLanguageStore.preview)
        )
    }

    func test_render_withoutAccessibilityIdentifier() {
        ViewRenderingHarness.render(
            InlineErrorText(message: "Select a port from the list")
                .environment(record_catch.AppLanguageStore.preview)
        )
    }
}
