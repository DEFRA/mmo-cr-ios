//
//  SyncErrorBanner.swift
//  record-catch
//
//  GOV.UK-style non-fatal notification banner shown when the most recent reference-data sync
//  failed (see ADR-0024 "Error UI"). Pinned below `OfflineBanner` in `ViewTemplate` so it is
//  visible on every screen without threading the sync status through each one individually.
//  Renders nothing while `status` is `.idle`/`.syncing`, and nothing at all while the device is
//  offline — being offline is handled by `OfflineBanner` and is never treated as a sync failure
//  (see `ReferenceDataSyncCoordinator.attemptSync(bypassThrottle:)`, which never even attempts a
//  sync while offline).
//

import SwiftUI

struct SyncErrorBanner: View {

    @Environment(\.referenceDataSyncStatus) private var syncStatus
    @Environment(AppLanguageStore.self) private var languageStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isFailed: Bool {
        if case .failed = syncStatus?.status { return true }
        return false
    }

    /// `true` once a sync has failed and **no** data has ever been saved for any dataset — the
    /// stronger of the two ADR-0024 messages ("fishing data has not downloaded" vs "we could not
    /// update fishing data, you can keep using what you already have").
    private var hasNoLocalData: Bool {
        if case let .failed(hasLocalData) = syncStatus?.status { return !hasLocalData }
        return false
    }

    var body: some View {
        Group {
            if isFailed {
                content
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(reduceMotion ? nil : .default, value: isFailed)
        .onChange(of: isFailed) { _, isFailed in
            guard isFailed else { return }
            announce()
        }
    }

    private var messageKey: String {
        hasNoLocalData ? "referenceData.sync.unavailable.message" : "referenceData.sync.failed.message"
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: AppSpacing.medium) {
                tag
                VStack(alignment: .leading, spacing: AppSpacing.small) {
                    LocalizedText(messageKey)
                        .font(AppTypography.bodySmall)
                        .foregroundStyle(AppColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    retryButton
                }
            }
            .padding(.horizontal, AppSpacing.medium)
            .padding(.vertical, AppSpacing.small)

            Rectangle()
                .fill(AppColors.divider)
                .frame(height: 1)
        }
        .background(AppColors.background)
        .accessibilityIdentifier("SyncErrorBanner")
    }

    private var tag: some View {
        LocalizedText("referenceData.sync.failed.tag")
            .font(AppTypography.bodySmall.weight(.bold))
            .foregroundStyle(AppColors.statusUnsentText)
            .padding(.horizontal, AppSpacing.small)
            .padding(.vertical, AppSpacing.xSmall)
            .background(AppColors.statusUnsentBackground)
            .accessibilityHidden(true)
    }

    private var retryButton: some View {
        Button {
            syncStatus?.retry()
        } label: {
            LocalizedText("referenceData.sync.retry")
                .font(AppTypography.bodySmall.weight(.semibold))
                .foregroundStyle(AppColors.linkText)
                .padding(.vertical, AppSpacing.xSmall)
        }
        .buttonStyle(.plain)
        .frame(minHeight: AppControlSize.minTapTarget, alignment: .leading)
        .accessibilityIdentifier("SyncErrorBanner.retry")
        .accessibilityLabel(languageStore.localized("referenceData.sync.retry"))
    }

    /// Posts a WCAG 2.2 4.1.3 "status message" VoiceOver announcement when the banner first
    /// appears — mirrors `OfflineBanner.announce(isOnline:)`.
    private func announce() {
        let key = hasNoLocalData ? "referenceData.sync.unavailable.message" : "referenceData.sync.failed.message"
        var message = AttributedString(languageStore.localized(key))
        message.accessibilitySpeechAnnouncementPriority = .default
        AccessibilityNotification.Announcement(message).post()
    }
}

#Preview("Update failed (has local data)") {
    VStack {
        SyncErrorBanner()
        Spacer()
    }
    .environment(\.referenceDataSyncStatus, StubReferenceDataSyncStatusObserver(status: .failed(hasLocalData: true)))
    .environment(AppLanguageStore.preview)
}

#Preview("Not yet downloaded (no local data)") {
    VStack {
        SyncErrorBanner()
        Spacer()
    }
    .environment(\.referenceDataSyncStatus, StubReferenceDataSyncStatusObserver(status: .failed(hasLocalData: false)))
    .environment(AppLanguageStore.preview)
}

#Preview("Idle (renders nothing)") {
    VStack {
        SyncErrorBanner()
        Text("Banner above is empty while idle/syncing")
    }
    .environment(\.referenceDataSyncStatus, StubReferenceDataSyncStatusObserver(status: .idle))
    .environment(AppLanguageStore.preview)
}
