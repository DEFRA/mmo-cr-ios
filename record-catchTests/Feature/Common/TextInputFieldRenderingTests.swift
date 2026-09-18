import XCTest
import SwiftUI
@testable import record_catch

/// Hosts `TextInputField` behind local `@State`. Uses the `record_catch.` module qualification
/// because `TextInputField.swift` is (per its own doc comment) compiled directly into both the
/// app module and this test target, so an unqualified reference could otherwise resolve to either
/// copy — qualifying targets the app module's copy, the one shipped to users.
private struct TextInputFieldHost: View {
    @State private var text: String
    let isSecure: Bool
    let didAttemptSubmit: Bool
    let errorMessage: String?

    init(text: String = "", isSecure: Bool = false, didAttemptSubmit: Bool = false, errorMessage: String? = nil) {
        _text = State(initialValue: text)
        self.isSecure = isSecure
        self.didAttemptSubmit = didAttemptSubmit
        self.errorMessage = errorMessage
    }

    var body: some View {
        record_catch.TextInputField(
            label: "Email address",
            hint: "We'll only use this to contact you about your account",
            isSecure: isSecure,
            text: $text,
            didAttemptSubmit: didAttemptSubmit,
            errorMessage: errorMessage
        )
    }
}

@MainActor
final class TextInputFieldRenderingTests: XCTestCase {

    func test_render_plainField_noError() {
        ViewRenderingHarness.render(TextInputFieldHost())
    }

    func test_render_plainField_withRequiredError() {
        ViewRenderingHarness.render(TextInputFieldHost(didAttemptSubmit: true))
    }

    func test_render_plainField_withExternalErrorMessage() {
        ViewRenderingHarness.render(
            TextInputFieldHost(text: "not-a-number", didAttemptSubmit: true, errorMessage: "Enter a whole number")
        )
    }

    func test_render_secureField_hidden() {
        ViewRenderingHarness.render(TextInputFieldHost(isSecure: true))
    }
}
