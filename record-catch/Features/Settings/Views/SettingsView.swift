//
//  SettingsView.swift
//  record-catch
//
//  Phase 2 bilingual Settings screen (see docs/design-specs/settings.md): analytics-
//  consent toggle (UI-only/stubbed — no analytics SDK), an account/menu link list, and
//  the "Gear used" row. "Sign out" shows a confirmation dialog before dismissing —
//  confirming remains an inert seam (see SettingsViewModel) since no session/auth
//  exists yet. Every other link destination is also a deliberately inert seam — no
//  navigation, auth or networking here.
//

import SwiftUI

struct SettingsView: View {

    @Environment(AppLanguageStore.self) private var languageStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var viewModel: SettingsViewModel

    /// - Parameters:
    ///   - router: the Settings tab's navigation router (see ADR-0007). Defaults to a fresh
    ///     `SettingsRouter` for previews/tests that don't care about navigation; `RootTabView`
    ///     always supplies the tab's real, shared instance so "My account" pushes onto the
    ///     visible `NavigationStack`.
    ///   - viewModel: injectable view model, used by previews/tests to seed preferences/gear used.
    init(router: SettingsRouter? = nil, viewModel: SettingsViewModel? = nil) {
        _viewModel = State(initialValue: viewModel ?? SettingsViewModel(router: router))
    }

    var body: some View {
        ViewTemplate(title: languageStore.localized("settings.title")) {
            content
                .environment(\.locale, languageStore.language.locale)
        }
        .confirmationDialog(
            languageStore.localized("settings.signOut.confirm.title"),
            isPresented: Binding(
                get: { viewModel.showSignOutConfirmation },
                set: { if !$0 { viewModel.cancelSignOutConfirmation() } }
            ),
            titleVisibility: .visible
        ) {
            Button(languageStore.localized("settings.signOut.confirm.confirm"), role: .destructive) {
                viewModel.confirmSignOut()
            }
            .accessibilityIdentifier("Settings.signOutConfirm.confirm")

            Button(languageStore.localized("settings.signOut.confirm.cancel"), role: .cancel) {
                viewModel.cancelSignOutConfirmation()
            }
            .accessibilityIdentifier("Settings.signOutConfirm.cancel")
        } message: {
            Text(languageStore.localized("settings.signOut.confirm.message"))
        }
    }

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: AppSpacing.large) {
            analyticsSection

            Divider()
                .overlay(AppColors.divider)

            menuList

            Divider()
                .overlay(AppColors.divider)
        }
    }

    @ViewBuilder
    private var analyticsSection: some View {
        @Bindable var viewModel = viewModel

        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Text(languageStore.localized("settings.analytics.heading"))
                .font(AppTypography.body.weight(.bold))
                .foregroundStyle(AppColors.textPrimary)
                .accessibilityAddTraits(.isHeader)

            analyticsBodyAndToggle

            LinkButton(title: languageStore.localized("settings.analytics.link")) {
                self.viewModel.openHowWeUseYourData()
            }
        }
    }

    /// The "We use this to improve…" text and its switch, side by side (switch to the right of the
    /// text) — see docs/design-specs/settings.md. Falls back to stacked (text above switch) at
    /// accessibility Dynamic Type sizes so the text never gets crushed into a narrow column next to
    /// a fixed-width switch (WCAG 2.2 AA).
    @ViewBuilder
    private var analyticsBodyAndToggle: some View {
        @Bindable var viewModel = viewModel
        let toggle = SettingsToggleRow(
            accessibilityIdentifier: "Settings.analyticsToggle",
            accessibilityLabel: languageStore.localized("settings.analytics.toggle.label"),
            accessibilityHint: languageStore.localized("settings.analytics.toggle.hint"),
            isOn: $viewModel.analyticsEnabled
        )

        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                ParagraphText(text: languageStore.localized("settings.analytics.body"), isHint: true)
                toggle
            }
        } else {
            HStack(alignment: .top, spacing: AppSpacing.medium) {
                ParagraphText(text: languageStore.localized("settings.analytics.body"), isHint: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                toggle
            }
        }
    }

    @ViewBuilder
    private var menuList: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsLinkRow(
                title: languageStore.localized("settings.link.myAccount"),
                accessibilityIdentifier: "Settings.link.myAccount",
                number: 1
            ) {
                viewModel.myAccountTapped()
            }

            Divider().overlay(AppColors.divider)

            SettingsLinkRow(
                title: languageStore.localized("settings.link.privacyNotice"),
                accessibilityIdentifier: "Settings.link.privacyNotice",
                number: 2
            ) {
                viewModel.privacyNoticeTapped()
            }

            Divider().overlay(AppColors.divider)

            SettingsLinkRow(
                title: languageStore.localized("settings.link.supportInformation"),
                accessibilityIdentifier: "Settings.link.supportInformation",
                number: 3
            ) {
                viewModel.supportInformationTapped()
            }

            Divider().overlay(AppColors.divider)

            SettingsLinkRow(
                title: languageStore.localized("settings.link.signOut"),
                accessibilityIdentifier: "Settings.link.signOut",
                number: 4
            ) {
                viewModel.signOutTapped()
            }

            Divider().overlay(AppColors.divider)

            SettingsValueRow(
                label: languageStore.localized("settings.gearUsed.label"),
                value: viewModel.gearUsed,
                emptyStateValue: languageStore.localized("settings.gearUsed.value.empty"),
                changeTitle: languageStore.localized("settings.gearUsed.change"),
                changeAccessibilityIdentifier: "Settings.gearUsed.change"
            ) {
                viewModel.changeGearTapped()
            }
        }
    }
}

#Preview("English") {
    SettingsView(viewModel: SettingsViewModel(preferenceStore: InMemoryAnalyticsPreferenceStore()))
        .environment(AppLanguageStore.preview)
}

#Preview("Welsh") {
    SettingsView(viewModel: SettingsViewModel(preferenceStore: InMemoryAnalyticsPreferenceStore()))
        .environment({
            let store = AppLanguageStore.preview
            store.language = .welsh
            return store
        }())
}

#Preview("Gear used recorded") {
    SettingsView(
        viewModel: SettingsViewModel(
            preferenceStore: InMemoryAnalyticsPreferenceStore(),
            gearUsed: "Seine nets"
        )
    )
    .environment(AppLanguageStore.preview)
}

#Preview("Max Dynamic Type") {
    SettingsView(viewModel: SettingsViewModel(preferenceStore: InMemoryAnalyticsPreferenceStore()))
        .environment(AppLanguageStore.preview)
        .environment(\.dynamicTypeSize, .accessibility5)
}
