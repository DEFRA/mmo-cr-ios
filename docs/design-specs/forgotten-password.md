# Design Spec — Forgotten password (self-service password reset)

Feature: self-service password reset for the DEFRA / MMO Catch Recording iOS app, via Microsoft
Entra External ID native authentication (MSAL SSPR flow). See
[ADR-0027](../adr/0027-self-service-password-reset.md) for the authoritative decision record and
[ADR-0022](../adr/0022-entra-external-id-native-authentication.md) for the base auth architecture
this extends.

Scope: real Entra-backed password reset (not a UI-only stub). Covers AC1–AC19 of the "Reset
forgotten password using a reset code" ticket.

## Entry point

"Forgotten your password?" on the Sign In screen (`SignIn.forgottenPasswordLink`) opens the
journey by pushing `PasswordResetRoute.resetPassword` onto `SignInFlowView`'s `NavigationStack`
(see [sign-in.md](sign-in.md)).

## Screens

### 1. Reset your password (`PasswordReset.*`)

- Heading (`PasswordReset.heading`), guidance text (`PasswordReset.guidance`).
- Email field (`PasswordReset.emailField`) — required, format-validated client-side
  (`PasswordReset.emailError`).
- "Send reset code" button (`PasswordReset.sendCodeButton`).
- A valid-shaped email **always** proceeds to "Enter your reset code" regardless of whether the
  account exists (AC3/AC5 — never reveal account existence; see ADR-0027 §3). A genuine service
  failure shows a generic, retryable error (`PasswordReset.formError`) and stays on screen (AC19).

### 2. Enter your reset code (`PasswordReset.enterCode.*`)

- Heading, guidance, code field (`PasswordReset.codeField`), "Continue"
  (`PasswordReset.continueButton`), "Send a new code" (`PasswordReset.sendNewCodeButton`).
- Invalid code → inline/form error, stays on screen (AC6).
- Expired code → a distinct "this code has expired" message (AC7); classified via MSAL error-code
  inspection with a local time-based fallback (ADR-0027 §5).
- Valid code → "Create a new password" (AC8).
- "Send a new code" cancels any in-flight MSAL state and returns to a **fresh** "Reset your
  password" screen with the email field blank (AC9). Implemented via `PasswordResetRouter.restart()`
  bumping an `attempt` counter and `.id(attempt)` on the destination view, forcing a new
  `ResetPasswordViewModel` rather than relying solely on `PasswordResetRoute`'s `Hashable`
  conformance.

### 3. Create a new password (`PasswordReset.createPassword.*`)

- New password field (`PasswordReset.newPasswordField`) and confirm field
  (`PasswordReset.confirmPasswordField`), both secure.
- **Design deviation (ADR-0027 §9, accepted):** Show/Hide rendered as a text button
  (`SecureToggleStyle.text`), not the app's usual eye icon, per the supplied design. The design's
  yellow focus-state fill is a web convention and is not reproduced (system focus styling is used
  instead).
- Client-side policy pre-check (8–256 characters, 3 of 4 character classes — ADR-0027 §6) runs
  before submission; a password that passes client-side but is rejected by Entra (e.g. banned
  password list) shows a generic "doesn't meet the requirements" error (AC16).
- "Save new password" button (`PasswordReset.savePasswordButton`) — copy fixes the ticket's design
  typo ("Save new password", not the typo'd original).
- On success, both password fields are cleared from memory and the view routes to "Your password
  has been reset" (AC16/AC17) — **no automatic sign-in** (ADR-0027 §4): the user must sign in with
  the new password deliberately, consistent with OWASP MASVS-AUTH (never carry a freshly-reset
  credential forward as an implicit session).

### 4. Your password has been reset (`PasswordReset.complete.*`)

- Confirmation heading, "Sign in" button (`PasswordReset.complete.signInButton`) returns to Sign In
  (`SignInView`), ending the reset journey (`PasswordResetRouter.finish()`).
- `.navigationBarBackButtonHidden(true)` — a user must not swipe back into a stale
  code/password screen after a security-sensitive action completes.

## Offline (AC18)

`OfflineAuthPanel` — a full-screen blue "You are offline" panel — covers Sign In and every screen
in this journey whenever `connectivityMonitor.isOnline == false` (ADR-0027 §7, narrows ADR-0019's
"no offline UI on Sign In" rule for this pre-authentication surface). Its "Sign in" button cancels
any in-flight reset state; because real offline detection cannot be toggled mid-journey, the panel
only dismisses once the device is actually back online.

## Email not opened automatically (ADR-0027 §10)

iOS does not grant apps a reliable, user-consented way to open the user's configured mail client
automatically. The screen therefore does not attempt to open Mail — it only tells the user to check
their email (generic "Check your email" messaging, folded into the "Enter your reset code" screen's
guidance rather than a separate interstitial, per ADR-0027 §9 deviation).

## Security notes

- **Never reveal account existence** — all MSAL errors that would otherwise reveal whether an
  account exists (user not found, no password set, etc.) collapse to the same outcome a genuine
  account would receive. This logic lives entirely in the pure, 100%-tested
  `PasswordResetErrorMapping` (see `record-catch/Core/Security/Auth/PasswordResetErrorMapping.swift`).
- Password fields are cleared from the view model immediately after every submit attempt,
  success or failure.
- `MSALNativePasswordResetter` (the real MSAL adapter) is excluded from SonarCloud coverage per the
  established ADR-0016 pattern (untestable without a live MSAL session) — every branch of decision
  logic it depends on is extracted into pure, fully-tested helpers instead.

## Reserved UI-test values (`UITestStubPasswordResetter`)

| Value | Outcome |
|---|---|
| `offline@example.com` | `.network` on request-code |
| `error@example.com` | `.serviceUnavailable` on request-code |
| code `11111111` | `.invalidCode` |
| code `22222222` | `.expired` |
| password `Weak-but-long1!` | `.doesNotMeetPolicy` (passes client-side checks, rejected server-side) |

## Localisation

40 new `passwordReset.*` keys added to `Localizable.xcstrings` (English translated; Welsh marked
`needs_review` pending content/Welsh-language review before release — see ADR-0027 §6 note on the
password-requirements copy).

## Tests

- Unit: `PasswordResetValidationTests`, `PasswordResetErrorMappingTests` (100% — security-critical),
  `PasswordResetRouterTests`, `ResetPasswordViewModelTests`, `EnterResetCodeViewModelTests`,
  `CreateNewPasswordViewModelTests`.
- UI: `ForgottenPasswordUITests` (full journey, AC1–AC19), plus updated `SignInUITests` and
  `OfflineBannerUITests` for the no-longer-inert link and the new `OfflineAuthPanel`.
