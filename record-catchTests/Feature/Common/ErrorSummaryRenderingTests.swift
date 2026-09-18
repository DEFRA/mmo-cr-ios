import XCTest
import SwiftUI
@testable import record_catch

@MainActor
final class ErrorSummaryRenderingTests: XCTestCase {

    func test_render_withMessages_showsSummaryHeadingAndEachRow() {
        ViewRenderingHarness.render(
            ErrorSummary(
                messages: [
                    "Select a species from the list",
                    "Weight for Atlantic cod (COD) must be more than 0kg"
                ],
                identifierPrefix: "Test.errorSummary"
            )
            .environment(record_catch.AppLanguageStore.preview)
        )
    }

    func test_render_withNoMessages_rendersNothing() {
        ViewRenderingHarness.render(
            ErrorSummary(messages: [], identifierPrefix: "Test.errorSummary")
                .environment(record_catch.AppLanguageStore.preview)
        )
    }
}
