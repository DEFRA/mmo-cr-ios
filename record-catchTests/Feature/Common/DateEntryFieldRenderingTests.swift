import XCTest
import SwiftUI
@testable import record_catch

/// Hosts `DateEntryField` behind local `@State`, since the view requires a `Binding<DateEntryValue>`.
private struct DateEntryFieldHost: View {
    @State private var value = DateEntryValue()
    let errorMessage: String?
    let errorParts: Set<DateEntryField.Part>

    var body: some View {
        DateEntryField(
            title: "When did you leave for your trip?",
            hint: "Enter the date you departed. For example, 31 3 2019",
            value: $value,
            didAttemptSubmit: errorMessage != nil,
            errorMessage: errorMessage,
            errorParts: errorParts,
            accessibilityIdentifierPrefix: "Test.date"
        )
        .environment(record_catch.AppLanguageStore.preview)
    }
}

@MainActor
final class DateEntryFieldRenderingTests: XCTestCase {

    func test_render_withNoError() {
        ViewRenderingHarness.render(DateEntryFieldHost(errorMessage: nil, errorParts: []))
    }

    func test_render_withWholeGroupError() {
        ViewRenderingHarness.render(
            DateEntryFieldHost(errorMessage: "Enter the date you left for your trip", errorParts: [])
        )
    }

    func test_render_withSpecificFieldError() {
        ViewRenderingHarness.render(
            DateEntryFieldHost(errorMessage: "Enter the day you left for your trip", errorParts: [.day])
        )
    }
}
