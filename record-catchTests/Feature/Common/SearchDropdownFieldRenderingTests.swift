import XCTest
import SwiftUI
@testable import record_catch

/// Hosts `SearchDropdownField` behind local `@State`. Uses `record_catch.` qualification for the
/// same dual-target-compilation reason documented on `TextInputFieldHost`.
private struct SearchDropdownFieldHost: View {
    @State private var query: String
    @State private var selectedOption: String?
    let didAttemptSubmit: Bool

    init(query: String = "", selectedOption: String? = nil, didAttemptSubmit: Bool = false) {
        _query = State(initialValue: query)
        _selectedOption = State(initialValue: selectedOption)
        self.didAttemptSubmit = didAttemptSubmit
    }

    var body: some View {
        record_catch.SearchDropdownField(
            label: "Add species",
            options: ["Atlantic cod (COD)", "Haddock (HAD)"],
            query: $query,
            selectedOption: $selectedOption,
            didAttemptSubmit: didAttemptSubmit,
            errorMessage: "Select a species from the list",
            errorAccessibilityIdentifier: "Test.error"
        )
    }
}

@MainActor
final class SearchDropdownFieldRenderingTests: XCTestCase {

    func test_render_empty() {
        ViewRenderingHarness.render(SearchDropdownFieldHost())
    }

    func test_render_withInvalidQuery_showsError() {
        ViewRenderingHarness.render(SearchDropdownFieldHost(query: "xyz", didAttemptSubmit: true))
    }

    func test_render_withValidSelection() {
        ViewRenderingHarness.render(
            SearchDropdownFieldHost(query: "Atlantic cod (COD)", selectedOption: "Atlantic cod (COD)")
        )
    }
}
