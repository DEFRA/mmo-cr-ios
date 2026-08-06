//
//  LocalizedText.swift
//  record-catch
//
//  A thin Text wrapper that resolves copy from the selected-language bundle so
//  the visible language changes live on iOS 16+ (see docs/adr/0002).
//

import SwiftUI

/// Renders a localised string resolved from the app's selected language.
///
/// Reads `AppLanguageStore` from the environment and resolves the key via the
/// selected-language `.lproj` bundle, then renders it as an `AttributedString`
/// carrying `.languageIdentifier(...)` so VoiceOver pronounces the content in
/// the correct language (WCAG 3.1.2 Language of Parts). Setting the environment
/// locale alone does NOT set the pronunciation language for `Text` built from a
/// runtime `String`, so the per-run language attribute is applied here.
struct LocalizedText: View {
    private let key: String

    @Environment(AppLanguageStore.self) private var languageStore

    init(_ key: String) {
        self.key = key
    }

    var body: some View {
        Text(Self.attributedString(languageStore.localized(key), language: languageStore.language))
    }

    /// Builds an `AttributedString` for `value` carrying the language identifier
    /// so VoiceOver uses the right pronunciation. Pure and static so the
    /// language-of-parts behaviour can be unit tested without a view host.
    static func attributedString(_ value: String, language: AppLanguage) -> AttributedString {
        var attributed = AttributedString(value)
        attributed.languageIdentifier = language.rawValue
        return attributed
    }
}
