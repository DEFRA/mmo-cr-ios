//
//  AppLanguageStore.swift
//  record-catch
//
//  App-level, persisted language selection injected at the app root.
//

import SwiftUI

/// Observable, persisted holder for the app's selected language.
///
/// Persists the choice via `@AppStorage("app.language")` so it survives launches.
/// Injected into the environment at the app root and read by the header toggle,
/// the locale environment and `LocalizedText`.
@MainActor
@Observable
final class AppLanguageStore {

    /// The `@AppStorage` key used to persist the selected language.
    static let storageKey = "app.language"

    private let defaults: UserDefaults

    var language: AppLanguage {
        didSet {
            defaults.set(language.rawValue, forKey: Self.storageKey)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // UI tests share `UserDefaults.standard`, so a language toggled in one test would
        // otherwise persist into the next and break identifier/label matching. When launched
        // for UI testing, start from a deterministic English baseline.
        if ProcessInfo.processInfo.arguments.contains("-uiTestResetLanguage") {
            self.language = .english
            defaults.set(AppLanguage.english.rawValue, forKey: Self.storageKey)
            return
        }
        let stored = defaults.string(forKey: Self.storageKey)
        self.language = stored.flatMap(AppLanguage.init(rawValue:)) ?? .english
    }

    /// Toggles between English and Welsh.
    func toggle() {
        language = language.opposite
    }

    /// Resolves `key` in the currently selected language.
    func localized(_ key: String) -> String {
        LocalizedBundle.string(key, language: language)
    }

    /// A safe, shared store for use in `#Preview`s so other features' previews
    /// don't crash when they forget to inject one. Backed by an isolated,
    /// throwaway `UserDefaults` suite so it never mutates real persisted state.
    static let preview = AppLanguageStore(
        defaults: UserDefaults(suiteName: "preview.appLanguageStore") ?? .standard
    )
}
