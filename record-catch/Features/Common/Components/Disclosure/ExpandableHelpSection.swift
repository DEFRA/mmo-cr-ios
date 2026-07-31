import SwiftUI

struct ExpandableHelpSection: View {
    let title: String
    let items: [HelpItem]

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            Button {
                isExpanded.toggle()
            } label: {
                HStack(alignment: .center, spacing: AppSpacing.small) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppColors.linkText)

                    Text(title)
                        .font(AppTypography.bodySmall)
                        .foregroundStyle(AppColors.linkText)
                        .underline()

                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint(isExpanded ? "Hides additional information" : "Reveals additional information")

            if isExpanded {
                VStack(alignment: .leading, spacing: AppSpacing.medium) {
                    ForEach(items) { item in
                        VStack(alignment: .leading, spacing: AppSpacing.small) {
                            Text(item.heading)
                                .font(AppTypography.bodySmall)
                                .foregroundStyle(AppColors.textPrimary)

                            ParagraphText(text: item.description)
                        }
                    }
                }
                .padding(.leading, AppSpacing.medium)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(AppColors.borderDefault)
                        .frame(width: 3)
                }
            }
        }
    }
}

struct HelpItem: Identifiable, Equatable {
    let id = UUID()
    let heading: String
    let description: String
}

#Preview {
    ExpandableHelpSection(
        title: "Understanding catch record statuses",
        items: [
            HelpItem(heading: "Unsent:", description: "Saved on your device and not yet submitted."),
            HelpItem(heading: "Submitted:", description: "Received by the MMO."),
            HelpItem(heading: "Amended:", description: "This record was changed after it was submitted."),
            HelpItem(heading: "Late:", description: "This record was received by the MMO after the required reporting timeframe.")
        ]
    )
    .padding()
}
