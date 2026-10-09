//
//  OfflineBanner.swift
//  record-catch
//
//  Red "Offline" status tag + message, rendered immediately below `ViewHeader` by
//  `ViewTemplate` whenever the device has no network path (see ADR-0019 and
//  docs/design-specs/offline-banner.md). Renders nothing at all while online.
//

import SwiftUI

/// GOV.UK-style offline indicator: a solid red "Offline" tag beside an explanatory message,
/// with a divider below. Pinned under the header (outside the scrollable content) so it stays
/// visible while the user scrolls.
///
/// DEFRA-governance deviation (recorded, not accidental — see ADR-0019 and the design spec):
/// the solid red/white tag follows the supplied Figma design rather than this app's existing
/// light-background status-tag convention (`SubmissionsTable`'s `statusLateBackground` etc.) and
/// the Feb 2026 GOV.UK Design System Tag refresh (lighter backgrounds, darker text). Contrast is
/// unaffected (white on `errorRed` measures 4.85:1, passing WCAG 2.2 AA 1.4.3).
struct OfflineBanner: View {

    @Environment(\.connectivityMonitor) private var connectivity
    @Environment(AppLanguageStore.self) private var languageStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// `nil` (no monitor configured for this context, e.g. an unrelated preview/test host) is
    /// treated as online, so the banner never spuriously appears when nothing has wired up
    /// connectivity monitoring.
    private var isOnline: Bool { connectivity?.isOnline ?? true }

    var body: some View {
        Group {
            if !isOnline {
                content
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
            }
        }
        // `.animation` (not `withAnimation` at the call site) so the insertion/removal driven by
        // `isOnline` changing is itself animated — `nil` entirely under Reduce Motion, a plain
        // cross-fade otherwise.
        .animation(reduceMotion ? nil : .default, value: isOnline)
        .onChange(of: isOnline) { _, isOnline in
            announce(isOnline: isOnline)
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: AppSpacing.medium) {
                tag
                LocalizedText("connectivity.offline.message")
                    .font(AppTypography.bodySmall)
                    .foregroundStyle(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, AppSpacing.medium)
            .padding(.vertical, AppSpacing.small)

            Rectangle()
                .fill(AppColors.divider)
                .frame(height: 1)
        }
        .background(AppColors.background)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            Self.accessibilityLabel(
                tag: languageStore.localized("connectivity.offline.tag"),
                message: languageStore.localized("connectivity.offline.message")
            )
        )
        .accessibilityIdentifier("OfflineBanner")
    }

    private var tag: some View {
        LocalizedText("connectivity.offline.tag")
            .font(AppTypography.bodySmall.weight(.bold))
            .foregroundStyle(AppColors.statusOfflineText)
            .padding(.horizontal, AppSpacing.small)
            .padding(.vertical, AppSpacing.xSmall)
            .background(AppColors.statusOfflineBackground)
            // The combined label above already conveys "Offline, <message>" as one unit; the
            // tag's own text would otherwise be read twice by VoiceOver.
            .accessibilityHidden(true)
    }

    /// Composes the combined VoiceOver label, e.g. "Offline, <message>". Pure and static so it
    /// can be unit tested without a view host (mirrors `WarningBox.accessibilityLabel`).
    static func accessibilityLabel(tag: String, message: String) -> String {
        "\(tag), \(message)"
    }

    /// Posts a WCAG 2.2 4.1.3 "status message" VoiceOver announcement for the online/offline
    /// transition. Going offline is posted at `.high` priority (important and time-sensitive —
    /// should interrupt); coming back online is `.default` (informational, must not cut the user
    /// off mid-sentence). Covers the "removal of status text" case the Understanding document
    /// calls out: losing the banner alone would be silent to a non-sighted user, so the "Back
    /// online" announcement conveys that removal explicitly.
    private func announce(isOnline: Bool) {
        let key = isOnline ? "connectivity.online.announcement" : "connectivity.offline.announcement"
        var message = AttributedString(languageStore.localized(key))
        message.accessibilitySpeechAnnouncementPriority = isOnline ? .default : .high
        AccessibilityNotification.Announcement(message).post()
    }
}

#Preview("Offline") {
    VStack {
        OfflineBanner()
        Spacer()
    }
    .environment(\.connectivityMonitor, StubConnectivityMonitor(isOnline: false))
    .environment(AppLanguageStore.preview)
}

#Preview("Online (renders nothing)") {
    VStack {
        OfflineBanner()
        Text("Banner above is empty when online")
    }
    .environment(\.connectivityMonitor, StubConnectivityMonitor(isOnline: true))
    .environment(AppLanguageStore.preview)
}
