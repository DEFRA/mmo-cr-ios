import SwiftUI

/// Minimal navigation surface the shared `ViewHeader` needs to render and drive its Back control.
///
/// `ViewHeader` lives in `Common` and must not depend on the concrete `CatchRecordRouter`
/// (a `CatchRecord` type), so it depends on this small protocol instead. The journey's router
/// conforms to it and is injected via `\.headerNavigator`. This keeps `Common` decoupled from the
/// feature layer (and keeps the unit-test source set self-contained).
@MainActor
protocol HeaderNavigating: AnyObject {
    /// Whether there is a screen to pop back to (drives Back-control visibility).
    var canGoBack: Bool { get }
    /// Pops the current screen, returning to the previous one.
    func pop()
}

private struct HeaderNavigatorKey: EnvironmentKey {
    static let defaultValue: (any HeaderNavigating)? = nil
}

extension EnvironmentValues {
    /// The optional navigator backing the shared header's Back control. `nil` in contexts without
    /// a navigation journey (e.g. previews and demo screens), where no Back control is shown.
    var headerNavigator: (any HeaderNavigating)? {
        get { self[HeaderNavigatorKey.self] }
        set { self[HeaderNavigatorKey.self] = newValue }
    }
}
