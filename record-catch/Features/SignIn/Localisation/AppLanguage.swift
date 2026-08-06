//
//  AppLanguage.swift
//  record-catch
//
//  App-level language selection for in-app English/Welsh switching.
//

import Foundation

/// The languages the app can be presented in.
///
/// The raw value is the ISO language code used both for `Locale` construction
/// and for locating the matching `.lproj` bundle when resolving String Catalog
/// entries (see `LocalizedBundle`).
enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case english = "en"
    case welsh = "cy"

    var id: String { rawValue }

    /// The language a toggle would switch *to* from this language.
    var opposite: AppLanguage {
        switch self {
        case .english: return .welsh
        case .welsh: return .english
        }
    }

    /// `Locale` matching this language, used for `.environment(\.locale, …)`
    /// and for correct VoiceOver pronunciation (WCAG 3.1.2).
    var locale: Locale {
        Locale(identifier: rawValue)
    }
}
