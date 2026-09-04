import SwiftUI

/// A GDS-style disclosure ("Details" component): a title button that reveals
/// arbitrary help content below it, marked with a left-hand rule.
///
/// Two ways to supply content:
/// - `items:` — the original heading + paragraph pairs (unchanged behaviour
///   for existing call sites: `HomeView`'s status-help section,
///   `TripFormDemoView`, `TripsOverviewDemoView`).
/// - `content:` — an arbitrary `@ViewBuilder` for richer sections (multiple
///   sub-headings, paragraphs, bullet lists) such as Home's
///   "How to record a catch" section.
struct ExpandableHelpSection<Content: View>: View {
    let title: String
    /// Optional stable accessibility identifier applied to the disclosure
    /// button, so UI tests can address a specific section unambiguously.
    let accessibilityIdentifier: String?
    @ViewBuilder let helpContent: () -> Content

    @State private var isExpanded = false

    init(
        title: String,
        accessibilityIdentifier: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.accessibilityIdentifier = accessibilityIdentifier
        self.helpContent = content
    }

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
            .modifier(OptionalAccessibilityIdentifier(identifier: accessibilityIdentifier))

            if isExpanded {
                helpContent()
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

extension ExpandableHelpSection {
    /// Convenience initializer preserving the original heading + paragraph
    /// pairs API used by the status-help section and the component demos.
    init(title: String, accessibilityIdentifier: String? = nil, items: [HelpItem]) where Content == HelpItemsList {
        self.init(title: title, accessibilityIdentifier: accessibilityIdentifier) {
            HelpItemsList(items: items)
        }
    }
}

/// Applies `.accessibilityIdentifier` only when a non-nil identifier is supplied.
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

struct HelpItem: Identifiable, Equatable {
    let id = UUID()
    let heading: String
    let description: String
}

/// Renders the original heading + paragraph list layout used by the `items:`
/// initializer, extracted so it can be built via the generic `content:` path.
struct HelpItemsList: View {
    let items: [HelpItem]

    var body: some View {
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
    }
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
