import SwiftUI

/// GOV.UK Design System "Error summary" — a box listing every validation error on the page,
/// shown above the heading when a submit fails.
///
/// Per GOV.UK guidance (https://design-system.service.gov.uk/components/error-summary/): always
/// shown when there is a validation error, even a single one; the heading is "There is a problem";
/// VoiceOver focus moves to the summary so screen-reader users are told immediately rather than
/// having to discover each field's error by touch. Each row visually and semantically matches its
/// field-level `InlineErrorText`.
struct ErrorSummary: View {
    /// The messages to list, already localised, in priority order.
    let messages: [String]
    /// Accessibility identifier prefix for the summary and its rows, e.g.
    /// `"CatchRecord.recordSpeciesWeights.errorSummary"`.
    let identifierPrefix: String

    @Environment(AppLanguageStore.self) private var languageStore
    @AccessibilityFocusState private var isFocused: Bool

    var body: some View {
        if !messages.isEmpty {
            VStack(alignment: .leading, spacing: AppSpacing.small) {
                Text(languageStore.localized("catchRecord.errorSummary.title"))
                    .font(AppTypography.body)
                    .fontWeight(.bold)
                    .foregroundStyle(AppColors.errorRed)
                    .accessibilityAddTraits(.isHeader)

                ForEach(Array(messages.enumerated()), id: \.offset) { index, message in
                    Text(message)
                        .font(AppTypography.bodySmall)
                        .foregroundStyle(AppColors.errorRed)
                        .accessibilityIdentifier("\(identifierPrefix).item.\(index)")
                }
            }
            .padding(AppSpacing.medium)
            .overlay(Rectangle().stroke(AppColors.errorRed, lineWidth: 4))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(identifierPrefix)
            .accessibilityFocused($isFocused)
            // Moves VoiceOver focus to the summary as soon as it appears, mirroring GOV.UK's
            // `govuk-error-summary` JavaScript behaviour of moving keyboard focus on page load.
            .onAppear { isFocused = true }
        }
    }
}

#Preview {
    ErrorSummary(
        messages: [
            "Select at least one species",
            "Weight for Atlantic cod (COD) must be more than 0kg"
        ],
        identifierPrefix: "Preview.errorSummary"
    )
    .padding()
    .environment(AppLanguageStore.preview)
}
