//
//  LocalizedBundle.swift
//  record-catch
//
//  Resolves localised strings from a specific language's `.lproj` bundle.
//
//  Rationale (see docs/adr/0002): on iOS 16, setting `.environment(\.locale, …)`
//  alone does NOT re-resolve String Catalog / `LocalizedStringKey` lookups — those
//  resolve against the app's preferred localisation fixed at launch. To switch the
//  visible copy live, we look strings up explicitly in the selected language's
//  compiled `.lproj` bundle.
//

import Foundation

/// Resolves keys from a selected language's `.lproj` bundle.
enum LocalizedBundle {

    /// Returns the resolved string for `key` in the given `language`.
    ///
    /// Falls back to the main bundle (development language) if the language's
    /// `.lproj` cannot be found, so a missing translation degrades gracefully
    /// rather than showing a raw key.
    static func string(_ key: String, language: AppLanguage) -> String {
        let bundle = bundle(for: language) ?? .main
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }

    private static func bundle(for language: AppLanguage) -> Bundle? {
        guard
            let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
            let bundle = Bundle(path: path)
        else {
            return nil
        }
        return bundle
    }
}
