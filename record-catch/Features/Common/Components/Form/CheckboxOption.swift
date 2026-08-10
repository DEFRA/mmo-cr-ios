import SwiftUI

/// A single multi-select checkbox row, mirroring `RadioOption` but for many-of-many selection.
///
/// Matches the GOV.UK Design System Checkboxes pattern (square control, label, selected trait for
/// assistive technology). Selection state is conveyed by both the tick glyph and the `.isSelected`
/// trait — never by colour alone.
struct CheckboxOption: View {
    let title: String
    /// Optional secondary line (e.g. a captured measurement summary such as "100mm mesh").
    let subtitle: String?
    let isSelected: Bool
    let action: () -> Void

    init(title: String, subtitle: String? = nil, isSelected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.subtitle = subtitle
        self.isSelected = isSelected
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: AppSpacing.medium) {
                ZStack {
                    Rectangle()
                        .stroke(AppColors.borderStrong, lineWidth: 1)
                        .frame(width: 24, height: 24)

                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(AppColors.textPrimary)
                    }
                }

                VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                    Text(title)
                        .font(AppTypography.bodySmall)
                        .foregroundStyle(AppColors.textPrimary)

                    if let subtitle {
                        Text(subtitle)
                            .font(AppTypography.bodySmall)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }

                Spacer()
            }
            .frame(minHeight: AppControlSize.buttonHeight, alignment: .center)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(subtitle.map { "\(title), \($0)" } ?? title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    VStack(alignment: .leading, spacing: AppSpacing.medium) {
        CheckboxOption(title: "Seine nets (not specified)", subtitle: "100mm mesh", isSelected: true) {}
        CheckboxOption(title: "Bottom trawl", isSelected: false) {}
    }
    .padding()
}
