//
//  SettingsView.swift
//  record-catch
//
//  Phase 2 bilingual Settings screen (see docs/design-specs/settings.md): analytics-
//  consent toggle (UI-only/stubbed — no analytics SDK), an account/menu link list, and
//  the "Gear used" row. "Sign out" and every link destination are deliberately inert
//  seams in this phase (see SettingsViewModel) — no navigation, auth or networking here.
//

import SwiftUI

struct SettingsView: View {

    @Environment(AppLanguageStore.self) private var languageStore
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

            ParagraphText(text: languageStore.localized("settings.analytics.body"), isHint: true)

            LinkButton(title: languageStore.localized("settings.analytics.link")) {
                self.viewModel.openHowWeUseYourData()
            }

            SettingsToggleRow(
                accessibilityIdentifier: "Settings.analyticsToggle",
                accessibilityLabel: languageStore.localized("settings.analytics.toggle.label"),
                accessibilityHint: languageStore.localized("settings.analytics.toggle.hint"),
                isOn: $viewModel.analyticsEnabled
            )
        }
    }

    @ViewBuilder
    private var menuList: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsLinkRow(
                title: languageStore.localized("settings.link.myAccount"),
                accessibilityIdentifier: "Settings.link.myAccount"
            ) {
                viewModel.myAccountTapped()
            }

            Divider().overlay(AppColors.divider)

            SettingsLinkRow(
                title: languageStore.localized("settings.link.privacyNotice"),
                accessibilityIdentifier: "Settings.link.privacyNotice"
            ) {
                viewModel.privacyNoticeTapped()
            }

            Divider().overlay(AppColors.divider)

            SettingsLinkRow(
                title: languageStore.localized("settings.link.supportInformation"),
                accessibilityIdentifier: "Settings.link.supportInformation"
            ) {
                viewModel.supportInformationTapped()
            }

            Divider().overlay(AppColors.divider)

            SettingsLinkRow(
                title: languageStore.localized("settings.link.signOut"),
                accessibilityIdentifier: "Settings.link.signOut"
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
