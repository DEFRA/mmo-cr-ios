//
//  DataPreparationView.swift
//  record-catch
//
//  "Getting your fishing data ready" — shown between sign-in/unlock and Home while the required
//  reference data (ports/species/gears) downloads (see `RootPhase.preparingData`, ADR-0024 "Data
//  before Home"). Mirrors `AppLockView`/`SignInView`'s plain, no-`ViewTemplate` layout (no GOV.UK
//  header/footer on this screen either — there is nothing in the app shell to show yet). Always
//  offers "Sign out" on failure so the user is never dead-ended, per accessibility.instructions.md.
//

import SwiftUI

struct DataPreparationView: View {

    @Environment(AppLanguageStore.self) private var languageStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var viewModel: DataPreparationViewModel

    init(viewModel: DataPreparationViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                content
                    .padding(.horizontal, AppSpacing.medium)
                    .padding(.top, AppSpacing.xLarge)
                    .padding(.bottom, AppSpacing.large)
            }
        }
        .background(AppColors.background)
        .environment(\.locale, languageStore.language.locale)
        .task { await viewModel.prepare() }
        .onChange(of: isFailed) { _, isFailed in
            guard isFailed else { return }
            announce()
        }
    }

    private var isFailed: Bool {
        if case .failed = viewModel.state { return true }
        return false
    }

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: AppSpacing.large) {
            Image("CrownLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .frame(maxWidth: .infinity, alignment: .center)
                .accessibilityHidden(true)

            LocalizedText("dataPreparation.heading")
                .font(AppTypography.pageTitle)
                .foregroundStyle(AppColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("DataPreparation.heading")

            switch viewModel.state {
            case .preparing:
                preparingContent
            case .failed(let isOffline):
                failedContent(isOffline: isOffline)
            }
        }
    }

    private var preparingContent: some View {
        VStack(spacing: AppSpacing.medium) {
            ProgressView()
                .accessibilityIdentifier("DataPreparation.progress")
            ParagraphText(text: languageStore.localized("dataPreparation.preparing.message"))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(languageStore.localized("dataPreparation.preparing.accessibilityLabel"))
    }

    private func failedContent(isOffline: Bool) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.large) {
            failureSummary(isOffline: isOffline)

            PrimaryButton(title: languageStore.localized("dataPreparation.retry")) {
                Task { await viewModel.prepare() }
            }
            .accessibilityIdentifier("DataPreparation.retry")

            SecondaryButton(title: languageStore.localized("dataPreparation.signOut")) {
                viewModel.onSignOut()
            }
            .accessibilityIdentifier("DataPreparation.signOut")
        }
    }

    private func failureSummary(isOffline: Bool) -> some View {
        let key = isOffline ? "dataPreparation.failed.offline.message" : "dataPreparation.failed.generic.message"
        return HStack(alignment: .top, spacing: AppSpacing.xSmall) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(AppColors.errorRed)
                .accessibilityHidden(true)
            LocalizedText(key)
                .font(AppTypography.error)
                .foregroundStyle(AppColors.errorRed)
        }
        .padding(AppSpacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(Rectangle().stroke(AppColors.errorRed, lineWidth: 2))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(languageStore.localized("a11y.errorPrefix")) \(languageStore.localized(key))")
        .accessibilityIdentifier("DataPreparation.error")
    }

    /// Posts a WCAG 2.2 4.1.3 "status message" VoiceOver announcement when preparation first
    /// fails — mirrors `SyncErrorBanner.announce()`.
    private func announce() {
        guard case .failed(let isOffline) = viewModel.state else { return }
        let key = isOffline ? "dataPreparation.failed.offline.message" : "dataPreparation.failed.generic.message"
        var message = AttributedString(languageStore.localized(key))
        message.accessibilitySpeechAnnouncementPriority = .default
        AccessibilityNotification.Announcement(message).post()
    }
}

#Preview("Preparing") {
    DataPreparationView(
        viewModel: DataPreparationViewModel(
            coordinator: PreviewReferenceDataPreparing(prepareResult: true),
            onReady: {},
            onSignOut: {}
        )
    )
    .environment(AppLanguageStore.preview)
}

#Preview("Failed (offline)") {
    DataPreparationView(
        viewModel: DataPreparationViewModel(
            coordinator: PreviewReferenceDataPreparing(prepareResult: false, isDeviceOnline: false),
            onReady: {},
            onSignOut: {}
        )
    )
    .environment(AppLanguageStore.preview)
}

#Preview("Failed (generic)") {
    DataPreparationView(
        viewModel: DataPreparationViewModel(
            coordinator: PreviewReferenceDataPreparing(prepareResult: false, isDeviceOnline: true),
            onReady: {},
            onSignOut: {}
        )
    )
    .environment(AppLanguageStore.preview)
}

/// Deterministic preview-only double — mirrors `StubReferenceDataSyncStatusObserver`'s role.
@MainActor
private final class PreviewReferenceDataPreparing: ReferenceDataPreparing {
    let isDeviceOnline: Bool
    private let prepareResult: Bool

    init(prepareResult: Bool, isDeviceOnline: Bool = true) {
        self.prepareResult = prepareResult
        self.isDeviceOnline = isDeviceOnline
    }

    func prepareRequiredData(timeout: TimeInterval) async -> Bool {
        prepareResult
    }
}
