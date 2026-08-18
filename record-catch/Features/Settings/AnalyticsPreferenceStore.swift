import Foundation

/// The user's local analytics-consent preference.
///
/// **UI-only for this phase** — no analytics SDK is wired up and no events are ever sent;
/// this only persists a local on/off preference so the Settings toggle has a real value
/// to bind to and survive relaunches. See docs/design-specs/settings.md.
///
/// - TODO: Real analytics consent (what "on" actually enables, retention, and any
///   DEFRA privacy-notice wording) needs a dedicated ADR and product/legal sign-off
///   before this preference drives any actual data collection.
nonisolated protocol AnalyticsPreferenceStoring: Sendable {
    /// Whether the user has opted in to analytics data collection.
    func isAnalyticsEnabled() -> Bool
    /// Persists the user's choice.
    func setAnalyticsEnabled(_ enabled: Bool)
}

/// `UserDefaults`-backed implementation, defaulting to opted-in (`true`) to match the
/// Figma mock's "Is On" state until product confirms the real default.
nonisolated final class UserDefaultsAnalyticsPreferenceStore: AnalyticsPreferenceStoring, @unchecked Sendable {
    static let storageKey = "settings.analyticsEnabled"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func isAnalyticsEnabled() -> Bool {
        guard defaults.object(forKey: Self.storageKey) != nil else { return true }
        return defaults.bool(forKey: Self.storageKey)
    }

    func setAnalyticsEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: Self.storageKey)
    }
}

/// In-memory, UI-only preference store — used by previews/tests so they never touch
/// real `UserDefaults` state.
nonisolated final class InMemoryAnalyticsPreferenceStore: AnalyticsPreferenceStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var enabled: Bool

    init(initialValue: Bool = true) {
        self.enabled = initialValue
    }

    func isAnalyticsEnabled() -> Bool {
        lock.withLock { enabled }
    }

    func setAnalyticsEnabled(_ enabled: Bool) {
        lock.withLock { self.enabled = enabled }
    }
}
