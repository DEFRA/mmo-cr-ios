//
//  LanguageToggleButton.swift
//  record-catch
//
//  Accessible header control that switches the app language between English and
//  Welsh. Shows the language it will switch *to*.
//

import SwiftUI

/// Header button that toggles the app language.
///
/// Displays the language it switches *to* ("Cymraeg" when in English, "English"
/// when in Welsh), meets the 44×44pt target, and exposes an accessible label and
/// hint. Wired to `AppLanguageStore` and persists across launches via that store.
struct LanguageToggleButton: View {

    @Environment(AppLanguageStore.self) private var languageStore

    private var target: AppLanguage { languageStore.language.opposite }

    private var titleKey: String {
        target == .welsh ? "header.language.toWelsh" : "header.language.toEnglish"
    }

    private var hintKey: String {
        target == .welsh ? "header.language.hint.toWelsh" : "header.language.hint.toEnglish"
    }

    var body: some View {
        Button {
            languageStore.toggle()
        } label: {
            LocalizedText(titleKey)
                .font(AppTypography.bodySmall)
                .foregroundStyle(.white)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(languageStore.localized(titleKey))
        .accessibilityHint(languageStore.localized(hintKey))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("Header.languageToggle")
    }
}
