import Foundation

/// Owns the navigation stack for the password-reset journey, pushed on top of `SignInView` by
/// `SignInFlowView` (ADR-0027 §8). Mirrors `SettingsRouter`/`CatchRecordRouter`: view models call
/// `push`/`pop`/`setPath` rather than building `NavigationLink`s directly, keeping "what screen
/// comes next" in one testable, `@Observable` place.
@MainActor
@Observable
final class PasswordResetRouter {

    private(set) var path: [PasswordResetRoute] = []
    /// Bumped every `start()`/`restart()` so the "Reset your password" route is a distinct path
    /// element each time, forcing a fresh `ResetPasswordViewModel` (AC9 — see `PasswordResetRoute`).
    private var attempt = 0

    init() {
        // Intentionally empty: `path` starts empty (the Sign In screen itself is the stack's
        // root, owned by `SignInFlowView`, not this router).
    }

    /// Begins the journey from the Sign In screen's "Forgotten your password?" link (AC1).
    func start() {
        attempt += 1
        path = [.resetPassword(attempt: attempt)]
    }

    /// Returns to a fresh "Reset your password" screen with the email field blank (AC9 — "Send a
    /// new code"). Distinct from `start()` only in intent; both produce the same single-element
    /// path with a new `attempt` token.
    func restart() {
        attempt += 1
        path = [.resetPassword(attempt: attempt)]
    }

    /// Pushes the next screen in the journey.
    func push(_ route: PasswordResetRoute) {
        path.append(route)
    }

    /// Pops the top screen. No-op at the root of this router's own stack (i.e. already showing
    /// "Reset your password").
    func pop() {
        guard path.count > 1 else { return }
        path.removeLast()
    }

    /// Ends the journey entirely, returning to Sign In (AC17's "Sign in" button, and the offline
    /// panel's "Sign in" action — ADR-0027 §7).
    func finish() {
        path = []
    }

    /// Replaces the whole path directly, so interactive dismissal (system back-swipe) is
    /// reflected here too (mirrors `CatchRecordRouter.setPath`).
    func setPath(_ newPath: [PasswordResetRoute]) {
        path = newPath
    }
}
