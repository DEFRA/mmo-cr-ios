import Foundation

/// Owns the navigation stack for the Settings tab (see docs/adr/0007-settings-tab-navigation.md).
///
/// Mirrors `CatchRecordRouter` (ADR-0003): bound to the Settings tab's own `NavigationStack(path:)`
/// at `RootTabView`, so `SettingsViewModel` never pushes a `NavigationLink` directly — it calls
/// `push(_:)`, keeping "what screen comes next" in one testable, `@Observable` place. Deliberately
/// a **separate** router from `CatchRecordRouter` and `AppTabRouter` — it owns only navigation
/// *within* the Settings tab, not which tab is selected (`AppTabRouter`) or the unrelated
/// Home-tab journey stack (`CatchRecordRouter`).
@MainActor
@Observable
final class SettingsRouter {

    private(set) var path: [SettingsRoute] = []

    init() {}

    /// Pushes the next screen in the Settings tab's stack.
    func push(_ route: SettingsRoute) {
        path.append(route)
    }

    /// Pops the top screen, returning to the previous one. No-op at the root.
    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    /// Clears the stack, returning to the Settings tab's root.
    func popToRoot() {
        path.removeAll()
    }

    /// Replaces the whole path directly.
    ///
    /// Used to keep the router as the source of truth for a two-way `NavigationStack(path:)`
    /// binding, so interactive dismissal (e.g. the system back-swipe gesture) is reflected here
    /// too, not just programmatic navigation via `push`/`popToRoot` (mirrors
    /// `CatchRecordRouter.setPath`).
    func setPath(_ newPath: [SettingsRoute]) {
        path = newPath
    }
}

extension SettingsRouter: HeaderNavigating {
    /// There is a screen to pop back to whenever the Settings tab's stack is non-empty.
    var canGoBack: Bool { !path.isEmpty }
}
