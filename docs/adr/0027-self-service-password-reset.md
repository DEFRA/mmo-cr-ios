# ADR 0027 — Self-service password reset via MSAL Native Authentication

- Status: Accepted
- Date: 2026-11
- Deciders: iOS engineering (security-reviewed)
- Context tags: security, authentication, offline-first, native-iOS, accessibility

## Context

ADR-0022 §8 deliberately left "Forgotten your password?" as an inert link, deferring self-service
password reset (SSPR) to a separate ticket. That ticket's acceptance criteria (AC1–AC19) are
answered by this ADR.

MSAL Native Authentication 2.17.0 (already pinned — ADR-0022 §1) ships a non-experimental
`resetPassword(parameters:delegate:)` API with four steps: start (`ResetPasswordStartDelegate`),
submit the emailed code (`ResetPasswordVerifyCodeDelegate`/`resendCode`), submit a new password
(`ResetPasswordRequiredDelegate`), and completion (`SignInAfterResetPasswordState` — discarded,
see §4). This mirrors the sign-in seam pattern already established.

Two things learned from reading the MSAL 2.17.0 source and Microsoft's native-authentication API
reference change the ADR-0022 configuration and the error-handling design:

- **Password reset requires the `oob` (email one-time-code) challenge type.** ADR-0022 §1
  configured MSAL with `challengeTypes: [.password]` only. Self-service password reset always
  issues an emailed code, so `.OOB` must be added: `[.OOB, .password]`.
- **MSAL has no distinct "expired code" error.** `VerifyCodeError` only exposes `isInvalidCode`;
  an expired continuation token surfaces as `generalError` with AADSTS error codes that must be
  inspected directly (Microsoft's reference lists `expired_token`, numeric code family ~552003).

## Decision

### 1. Challenge types become `[.OOB, .password]` (supersedes ADR-0022 §1)

`MSALNativeAuthenticator`'s and the new `MSALNativePasswordResetter`'s configuration both use
`challengeTypes: [.OOB, .password]`. This is a shared tenant/app-registration setting, not
per-flow, so sign-in's own negotiation is unaffected in practice: an unexpected `codeRequired`
step during sign-in already maps to `.serviceUnavailable` (ADR-0022 §3), so adding `.OOB`
introduces no new sign-in behaviour, only a regression test confirming this.

### 2. One new seam: `PasswordResetting`, mirroring `Authenticating`

`Core/Security/Auth/PasswordResetting.swift` defines a `@MainActor` protocol:
`requestCode(email:)`, `verifyCode(_:)`, `submitNewPassword(_:)`, `cancel()`. Only
`MSALNativePasswordResetter` imports MSAL; `FakePasswordResetter`/`UITestStubPasswordResetter`
are in-memory doubles, exactly as `Authenticating`/`MSALNativeAuthenticator` (ADR-0022 §2).

Outcomes are typed per step (`ResetCodeRequestOutcome`, `ResetCodeVerificationOutcome`,
`NewPasswordOutcome`) rather than one shared enum, since each step has different failure shapes
(e.g. only the final step can reject a password as too weak).

### 3. Never reveal whether an account exists (security-critical, 100%-covered)

Per the ticket's AC3 security note and the existing ADR-0022 §3 precedent: `user_not_found`,
`invalid_username` and `user_does_not_have_password` from `/resetpassword/start` all map to
`.codeSent` — the same outcome as a real account — and the app never retains any MSAL state for
that attempt. A subsequent code submission for a non-existent account therefore has no
continuation token to validate against and deterministically returns `.invalidCode`, which is
indistinguishable in the UI from a genuine wrong code. This mirrors a real account's experience
closely enough that the API cannot be used to enumerate registered email addresses from the app's
behaviour. The residual risk that Entra's own `/resetpassword/start` response timing or any
server-side rate limiting could still leak signal is a known limitation, out of this app's control
— flagged for the Entra tenant team, not solved here.

### 4. No automatic sign-in after reset

Per the ticket's design (AC17: a confirmation screen with a "Sign in" button, not an automatic
session), the `SignInAfterResetPasswordState` MSAL returns on completion is discarded. The user
explicitly signs in again with their new password, through the existing `Authenticating` seam.

### 5. Expired code: AADSTS-code inspection plus a local lifetime fallback

Since MSAL collapses an expired continuation token into `generalError`, `MSALNativePasswordResetter`
inspects `errorCodes` for the expired-token family (reference: `expired_token`) to report
`.expired` distinctly from `.invalidCode`. As a defensive fallback — in case a future MSAL/Entra
response doesn't surface a recognisable code — `EnterResetCodeViewModel` also tracks how long ago
the code was requested and treats a code-verification failure after a configured lifetime as
`.expired` rather than `.invalidCode`, so the user is never stuck retrying a code that cannot
possibly still be valid. The exact server-side lifetime must be confirmed with the Entra tenant
team (the design shows "5 minutes"); `PasswordResetConfiguration.codeLifetime` is the single
place this is adjusted.

### 6. App-side password policy check, ahead of Entra's own validation

Entra's combined password policy requires 8–256 characters and 3 of 4 character-class categories
(upper/lower/number/symbol), and separately rejects banned or recently-used passwords. The
ticket's design hint only shows "at least 8 characters" — checking length alone would let a user
submit a password Entra is guaranteed to reject. `PasswordResetValidation` checks length and
character-class count client-side (so the inline error is immediate, matching GOV.UK's "prevent
errors" pattern already used elsewhere — e.g. `TextInputField`'s decimal-input sanitisation);
Entra's own banned/recently-used/too-long rejections, which cannot be checked client-side, all
collapse to one generic `.doesNotMeetPolicy` outcome. The exact character-class copy is flagged
**needs content review**, since the design's hint text under-states the real requirement.

### 7. Offline: request never sent; one shared "You are offline" panel

Every `PasswordResetting` method checks `ConnectivityMonitoring.isOnline` before calling MSAL,
exactly as `MSALNativeAuthenticator` does today — consistent with ADR-0022's "never silently
claim success offline" principle. A new `OfflineAuthPanel` component (full-screen, matching the
supplied design) is shown whenever the device is offline on the Sign In screen or anywhere inside
the password-reset flow. Its "Sign in" button ends the reset journey and returns to Sign In.

**This supersedes ADR-0019's "no offline UI on the Sign In screen" rule for the pre-authentication
surface**: before ADR-0022/ADR-0027, there was nothing to retry on Sign In (every tap always
"succeeded"); now that Sign In and password reset perform real network requests, surfacing offline
state there is necessary (DEFRA mobile standard: "a user must never be stuck on a dead control").
Post-authentication screens keep the existing top-of-content `OfflineBanner` unchanged — this ADR
only concerns the pre-authentication surface.

### 8. Navigation: a typed router, mirroring `SettingsRouter`/`CatchRecordRouter`

`PasswordResetRoute` (`.enterCode`, `.createPassword`, `.complete`) and `@Observable
PasswordResetRouter` (`start()`, `restart()`, `finish()`) drive a `NavigationStack` hosted by a new
`SignInFlowView`, which wraps `SignInView` as its root. `restart()` (AC9 — "Send a new code"
returns to Reset your password with a blank email) always constructs a **new**
`ResetPasswordViewModel`, never reuses one with a cleared field, so a previously entered email
cannot be retained by any residual view-model state.

### 9. Accepted design deviations (recorded in the Design Spec, not silently applied)

Per the figma-design instructions, the design is followed and each deviation recorded rather than
silently "corrected":

1. **System Back navigation is kept** on every reset screen (the supplied designs show none) — a
   user who opens the journey by mistake must be able to leave it.
2. **Show/Hide password controls are text buttons**, not the icon toggle `TextInputField` uses
   elsewhere; the design's yellow fill is a web focus style and is not reproduced — iOS provides
   its own focus indication.
3. **Button copy fixes the design's apparent typo** — "Save new password" (the design image reads
   "Save new pasword").
4. **No separate "Check your email" screen.** The Reset-your-password screen's existing hint
   ("If an account exists for this email address, we'll send a reset code") and the Enter-your-
   reset-code screen's guidance together satisfy the ticket's description without an extra screen.

### 10. The device email app is never opened automatically

Per the ticket's "requirement to confirm": iOS has no public API to open the Mail app's inbox
(only `mailto:`, which composes a new message). The user opens their email client themselves, as
already implied by "the user must be able to access the email" (AC3/AC4) rather than any stated
automatic behaviour. The reset-code field uses `.textContentType(.oneTimeCode)` so iOS can offer
the code via AutoFill from a delivered Mail notification where the system supports it — a
reasonable, non-bespoke mitigation.

## Consequences

- ADR-0022 §1's challenge types and §8 ("Forgot Password stays an inert link") are superseded by
  §§1 and 8 above; an addendum is added to ADR-0022 recording this.
- ADR-0019's "no offline UI on the Sign In screen" exception is narrowed per §7 above; an addendum
  is added to ADR-0019.
- `MSALNativePasswordResetter.swift` is excluded from SonarCloud coverage on the same grounds as
  `MSALNativeAuthenticator.swift` (ADR-0016 §4) — a thin, untestable-in-CI wrapper around the real
  MSAL SDK with no network-free seam; all decision logic is pulled into pure, 100%-covered
  helpers (`PasswordResetValidation`, the error-code classification helpers).
- **Standing obligations carried forward:**
  1. Confirm the real reset-code lifetime with the Entra tenant team (§5) and content-review the
     password-policy hint copy (§6) and the one generic service-error message, before release.
  2. Self-service password reset requires the Entra tenant team to enable SSPR and the Email OTP
     authentication method for customer users, and to confirm the app registration's user flow
     includes "Email with password" (see Microsoft's enablement guide) — tracked as DevOps/Entra
     tenant-team work, out of scope for this ADR (mirrors ADR-0022's ownership split).
  3. Welsh translations for all new strings are machine-drafted placeholders pending review by a
     Welsh speaker.

## References

- ADR-0022 (Entra External ID native authentication — especially §§1–3, 8, 10), ADR-0019
  (connectivity monitoring / offline indicator), ADR-0016 (coverage strategy and scoped
  exclusions).
- Microsoft, *Native authentication API reference* (self-service password reset section) —
  https://learn.microsoft.com/en-us/entra/identity-platform/reference-native-authentication-api
- Microsoft, *Enable self-service password reset* (External ID) —
  https://learn.microsoft.com/en-us/entra/external-id/customers/how-to-enable-password-reset-customers
- Microsoft, *Combined password policy and check for weak passwords* —
  https://learn.microsoft.com/en-us/entra/identity/authentication/concept-password-ban-bad-combined-policy
- `microsoft-authentication-library-for-objc` 2.17.0 source (`ResetPasswordDelegates.swift`,
  `ResetPasswordStates.swift`, `ResetPasswordStartError.swift`, `VerifyCodeError.swift`,
  `PasswordRequiredError.swift`, `MSALNativeAuthResetPasswordContinueResponseError.swift`).
- OWASP MASVS-AUTH — https://mas.owasp.org/MASVS/
