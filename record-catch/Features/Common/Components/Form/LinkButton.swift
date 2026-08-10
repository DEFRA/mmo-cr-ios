import SwiftUI

/// A GOV.UK-style inline text link that performs an action (not navigation chrome).
///
/// Used for in-page actions such as "Add a species", "Remove weight below minimum size retained
/// (kg)". Rendered as underlined link-blue text with a full 44pt-tall tappable area to meet the
/// WCAG 2.2 target-size minimum, and exposed to VoiceOver as a button (a link that acts on the page,
/// per GOV.UK guidance, is announced with the `.isButton` trait).
struct LinkButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppTypography.bodySmall)
                .foregroundStyle(AppColors.linkText)
                .underline()
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, minHeight: AppControlSize.buttonHeight, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isButton)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: AppSpacing.small) {
        LinkButton(title: "Add a species") {}
        LinkButton(title: "Remove weight below minimum size retained (kg)") {}
    }
    .padding()
}
