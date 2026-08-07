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
        VStack(spacing: AppSpacing.xSmall) {
            // Navigation row — GDS: Previous pinned leading, page numbers centred,
            // Next pinned trailing. Fixed to the tap-target height so it never inflates.
            HStack(spacing: AppSpacing.small) {
                if state.canGoPrevious {
                    previousButton
                }

                Spacer(minLength: AppSpacing.small)

                HStack(spacing: AppSpacing.small) {
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
                }

                Spacer(minLength: AppSpacing.small)

                if state.canGoNext {
                    nextButton
                }
            }
            .frame(minHeight: minTarget)

            // GDS: the "Showing X to Y of Z" results text sits on its own line,
            // not inline with the page numbers.
            showingText
        }
        .fixedSize(horizontal: false, vertical: true)
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
                .foregroundStyle(isCurrent ? AppColors.background : AppColors.linkText)
                .frame(minWidth: minTarget, minHeight: minTarget)
                .background(
                    RoundedRectangle(cornerRadius: 2)
                        .fill(isCurrent ? AppColors.govBlue : Color.clear)
                )
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

#Preview("Multiple pages") {
    PaginationControls(
        state: PaginationState(currentPage: 2, totalPages: 5, pageSize: 4, totalItems: 20)
    )
    .padding()
    .environment(AppLanguageStore.preview)
}

#Preview("Single page") {
    PaginationControls(
        state: PaginationState(currentPage: 1, totalPages: 1, pageSize: 4, totalItems: 4)
    )
    .padding()
    .environment(AppLanguageStore.preview)
}
