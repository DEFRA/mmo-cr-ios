import SwiftUI

/// A single inline validation error row: a red exclamation icon (never colour alone — WCAG 1.4.1)
/// plus the message text, exposed to VoiceOver as one element prefixed with "Error:" /
/// "Gwall:" (`a11y.errorPrefix`).
///
/// Extracted from the near-identical error rows duplicated across `DateEntryField`, `AddGearView`,
/// `AddSpeciesView` and `RecordSpeciesWeightsView` so every new validation message added in this
/// change (and any future one) gets the same accessible treatment for free.
struct InlineErrorText: View {
    let message: String
    /// Accessibility identifier for the error text, e.g. `"CatchRecord.addGear.error"`, so UI
    /// tests can assert the exact rendered message.
    var accessibilityIdentifier: String?

    @Environment(AppLanguageStore.self) private var languageStore

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.xSmall) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(AppColors.errorRed)
                .accessibilityHidden(true)
            Text(message)
                .font(AppTypography.error)
                .foregroundStyle(AppColors.errorRed)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(languageStore.localized("a11y.errorPrefix")) \(message)")
        .modifier(OptionalAccessibilityIdentifier(identifier: accessibilityIdentifier))
    }
}

/// Applies `.accessibilityIdentifier` only when one is supplied, so `InlineErrorText` can be used
/// both where a stable identifier is needed (screen-level errors) and where it is not.
private struct OptionalAccessibilityIdentifier: ViewModifier {
    let identifier: String?

    func body(content: Content) -> some View {
        if let identifier {
            content.accessibilityIdentifier(identifier)
        } else {
            content
        }
    }
}

#Preview {
    InlineErrorText(message: "Select a port from the list", accessibilityIdentifier: "Preview.error")
        .padding()
        .environment(AppLanguageStore.preview)
}
