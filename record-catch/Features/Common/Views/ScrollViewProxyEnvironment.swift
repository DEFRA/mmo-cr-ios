import SwiftUI

/// Exposes the enclosing `ScrollView`'s `ScrollViewProxy` (set by `ViewTemplate`) to any
/// descendant view, so a field nested deep in a form (e.g. `SearchDropdownField`) can scroll
/// itself — or content that appears below it, like search results — into view above the
/// keyboard. SwiftUI's built-in keyboard avoidance only guarantees the *focused* control is
/// visible; it does not know about sibling content (like a results list) that appears after
/// focus, which is otherwise left hidden behind the keyboard.
private struct ScrollViewProxyKey: EnvironmentKey {
    static let defaultValue: ScrollViewProxy? = nil
}

extension EnvironmentValues {
    var scrollViewProxy: ScrollViewProxy? {
        get { self[ScrollViewProxyKey.self] }
        set { self[ScrollViewProxyKey.self] = newValue }
    }
}
