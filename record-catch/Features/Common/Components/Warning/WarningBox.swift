import SwiftUI

/// GOV.UK-style important-information box: a gov-blue bordered container with a
/// bold "Important" tag and a message. Copy is routed through the language store.
struct WarningBox: View {

    let tagKey: String
    let messageKey: String

    @Environment(AppLanguageStore.self) private var languageStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Solid gov-blue banner with white "Important" text.
            LocalizedText(tagKey)
                .font(AppTypography.bodySmall.weight(.bold))
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AppSpacing.medium)
                .padding(.vertical, AppSpacing.small)
                .background(AppColors.govBlue)

            // White body with the message.
            LocalizedText(messageKey)
                .font(AppTypography.bodySmall)
                .foregroundStyle(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(AppSpacing.medium)
        }
        .overlay(
            Rectangle().stroke(AppColors.govBlue, lineWidth: 2)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            Self.accessibilityLabel(
                tag: languageStore.localized(tagKey),
                message: languageStore.localized(messageKey)
            )
        )
        .accessibilityIdentifier("Home.warningBox")
    }

    /// Composes the combined VoiceOver label, e.g. "Important, <message>".
    /// Pure and static so it can be unit tested without a view host.
    static func accessibilityLabel(tag: String, message: String) -> String {
        "\(tag), \(message)"
    }
}

#Preview {
    WarningBox(tagKey: "home.warning.tag", messageKey: "home.warning.message")
        .padding()
        .environment(AppLanguageStore.preview)
}
