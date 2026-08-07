import SwiftUI

/// GDS-pattern pagination control: Previous · showing-range · page numbers · Next.
///
/// Presentation-only. All derivable logic lives in the pure `PaginationState`.
/// Copy is routed through `AppLanguageStore` so it carries the correct language.
struct PaginationControls: View {

    let state: PaginationState
    var onSelectPage: (Int) -> Void = { _ in }
    var onPrevious: () -> Void = {}
    var onNext: () -> Void = {}

    @Environment(AppLanguageStore.self) private var languageStore

    private var minTarget: CGFloat { 44 }

    var body: some View {
        HStack(spacing: AppSpacing.medium) {
            if state.canGoPrevious {
                previousButton
            }

            showingText

            ForEach(Array(state.pageItems.enumerated()), id: \.offset) { _, item in
                switch item {
                case let .page(number):
                    pageButton(number)
                case .ellipsis:
                    Text("…")
                        .font(AppTypography.bodySmall)
                        .foregroundStyle(AppColors.textPrimary)
                        .accessibilityHidden(true)
                }
            }

            if state.canGoNext {
                nextButton
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(languageStore.localized("home.pagination.a11y.container"))
    }

    private var previousButton: some View {
        Button(action: onPrevious) {
            HStack(spacing: AppSpacing.xSmall) {
                Image(systemName: "chevron.left")
                    .accessibilityHidden(true)
                Text(languageStore.localized("home.pagination.previous"))
            }
            .font(AppTypography.bodySmall)
            .foregroundStyle(AppColors.linkText)
            .underline()
            .frame(minWidth: minTarget, minHeight: minTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(languageStore.localized("home.pagination.a11y.previous"))
        .accessibilityIdentifier("Home.pagination.previous")
    }

    private var nextButton: some View {
        Button(action: onNext) {
            HStack(spacing: AppSpacing.xSmall) {
                Text(languageStore.localized("home.pagination.next"))
                Image(systemName: "chevron.right")
                    .accessibilityHidden(true)
            }
            .font(AppTypography.bodySmall)
            .foregroundStyle(AppColors.linkText)
            .underline()
            .frame(minWidth: minTarget, minHeight: minTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(languageStore.localized("home.pagination.a11y.next"))
        .accessibilityIdentifier("Home.pagination.next")
    }

    private func pageButton(_ number: Int) -> some View {
        let isCurrent = number == state.currentPage
        return Button {
            onSelectPage(number)
        } label: {
            Text(String(number))
                .font(AppTypography.bodySmall)
                .fontWeight(isCurrent ? .bold : .regular)
                .foregroundStyle(isCurrent ? AppColors.textPrimary : AppColors.linkText)
                .frame(minWidth: minTarget, minHeight: minTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(pageLabel(number))
        .accessibilityAddTraits(isCurrent ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("Home.pagination.page.\(number)")
    }

    private var showingText: some View {
        Text(state.showingText(format: languageStore.localized("home.pagination.showing")))
            .font(AppTypography.bodySmall)
            .foregroundStyle(AppColors.textSecondary)
            .accessibilityIdentifier("Home.pagination.showing")
    }

    private func pageLabel(_ number: Int) -> String {
        String(format: languageStore.localized("home.pagination.page"), String(number))
    }
}

#Preview {
    PaginationControls(
        state: PaginationState(currentPage: 1, totalPages: 1, pageSize: 4, totalItems: 4)
    )
    .padding()
    .environment(AppLanguageStore.preview)
}
