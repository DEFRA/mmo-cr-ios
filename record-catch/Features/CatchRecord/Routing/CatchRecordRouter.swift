import Foundation

/// Owns the navigation stack for the "Create a catch record" journey.
///
/// Bound to a single `NavigationStack(path:)` at the journey's host view (see ADR-0003). Screens
/// and view models never push `NavigationLink`s directly — they call the methods here, keeping
/// "what screen comes next" logic in one testable, `@Observable` place.
@MainActor
@Observable
final class CatchRecordRouter {

    private(set) var path: [CatchRecordRoute] = []

    init() {}

    /// Starts the journey from an existing draft (unsent) record.
    func startFromDraft(_ row: SubmissionRow) {
        path = [.draftAction(row)]
    }

    /// Starts a brand new catch record from Home's "Create a new catch record" button.
    func startNew() {
        path = [.selectVessel]
    }

    /// Pushes the next screen in the journey.
    func push(_ route: CatchRecordRoute) {
        path.append(route)
    }

    /// Clears the stack, returning to the journey's host root (e.g. after a confirmed delete).
    func popToRoot() {
        path.removeAll()
    }

    /// Replaces the whole path directly.
    ///
    /// Used to keep the router as the source of truth for a two-way `NavigationStack(path:)`
    /// binding, so interactive dismissal (e.g. the system back-swipe gesture) is reflected here
    /// too, not just programmatic navigation via `push`/`popToRoot`.
    func setPath(_ newPath: [CatchRecordRoute]) {
        path = newPath
    }
}
