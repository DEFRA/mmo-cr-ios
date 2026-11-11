import Foundation

/// The screens reachable within the password-reset journey, pushed onto `SignInFlowView`'s
/// `NavigationStack` on top of `SignInView` (ADR-0027 §8). Mirrors `SettingsRoute`/`CatchRecordRoute`.
enum PasswordResetRoute: Hashable {
    /// "Reset your password" (AC1–AC3, AC9). `attempt` changes every time the journey (re)starts
    /// (first entry, or "Send a new code" from the code screen) so SwiftUI treats it as a
    /// distinct path element and rebuilds a *fresh* `ResetPasswordViewModel` with a blank email —
    /// never one that retains a previously entered address (ADR-0027 §8, AC9).
    case resetPassword(attempt: Int)
    /// "Enter your reset code" (AC5).
    case enterCode
    /// "Create a new password" (AC11).
    case createPassword
    /// "Your password has been reset" (AC17).
    case complete
}
