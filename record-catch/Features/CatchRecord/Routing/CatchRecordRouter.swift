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

    init() {
        // Intentionally empty: `path` is already initialised to an empty stack above; the
        // journey is started explicitly via `startFromDraft(_:)`/`startNew()`.
    }

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

    /// Pops the top screen, returning to the previous one. No-op at the root.
    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    /// Replaces the top screen of the stack with `route`, instead of pushing on top of it.
    ///
    /// Used once "Save and continue" on the vessel screen commits the vessel (see
    /// `SelectVesselViewModel.submit()`): vessel selection is a one-time first step of the journey
    /// (see ADR-0013 amendment — vessel cannot be changed once a record exists), so `.selectVessel`
    /// is removed from the stack rather than left behind the next screen. Back, or the interactive
    /// swipe-back gesture, on the screen that follows then leaves the journey (returning to Home)
    /// instead of re-opening vessel selection. Falls back to pushing `route` as the sole entry when
    /// the stack is empty, so this is still safe to call from a root-level screen.
    func replaceCurrent(with route: CatchRecordRoute) {
        guard !path.isEmpty else {
            path = [route]
            return
        }
        path[path.count - 1] = route
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

    /// Whether the current navigation state should trigger a draft save (see `CatchRecordHostView`).
    ///
    /// A draft is only ever worth persisting once the vessel step has actually been **committed** —
    /// not while still showing `.selectVessel` itself, so going back (or swiping back) from vessel
    /// selection before an answer is saved never creates an empty or stale draft row. It also stops
    /// once `.submissionSuccess` is reached: the persisted draft has just been deleted by a
    /// successful submit (`CheckYourAnswersViewModel.submit(isOnline:)`), and a save reaching the host
    /// view's observers after that deletion must not resurrect it as a fresh Unsent row. A pure,
    /// static function (rather than an instance method) so it is trivially unit-testable against any
    /// `path`/`vessel` combination without constructing a router.
    static func shouldPersistDraft(path: [CatchRecordRoute], vessel: String?) -> Bool {
        guard vessel != nil, let top = path.last else { return false }
        switch top {
        case .selectVessel, .submissionSuccess:
            return false
        default:
            return true
        }
    }
}

extension CatchRecordRouter: HeaderNavigating {
    /// There is a screen to pop back to whenever the journey stack is non-empty.
    var canGoBack: Bool { !path.isEmpty }
}
