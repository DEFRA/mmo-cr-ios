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
/// Displays a short bold abbreviation of the language it switches *to* ("CYM"
/// when in English, "ENG" when in Welsh), meets the 44×44pt target, and exposes
/// a descriptive accessible label ("Switch to Welsh" / "Switch to English") so
/// VoiceOver announces the full action rather than the abbreviation. Wired to
/// `AppLanguageStore` and persists across launches via that store.
struct LanguageToggleButton: View {

    @Environment(AppLanguageStore.self) private var languageStore

    /// Text colour for the toggle. Defaults to white for use on the coloured
    /// header bar; screens that place the toggle on a light background (e.g. the
    /// headerless Sign In) can pass a darker colour for contrast.
    var foregroundColor: Color = .white

    private var target: AppLanguage { languageStore.language.opposite }

    private var titleKey: String {
        target == .welsh ? "header.language.toWelsh" : "header.language.toEnglish"
    }

    /// Descriptive action text ("Switch to Welsh" / "Switch to English") used as
    /// the VoiceOver label so the spoken control is clear even though the visible
    /// text is an abbreviation.
    private var accessibilityLabelKey: String {
        target == .welsh ? "header.language.hint.toWelsh" : "header.language.hint.toEnglish"
    }

    var body: some View {
        Button {
            languageStore.toggle()
        } label: {
            LocalizedText(titleKey)
                .font(AppTypography.bodySmall.weight(.bold))
                .foregroundStyle(foregroundColor)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(languageStore.localized(accessibilityLabelKey))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("Header.languageToggle")
    }
}
