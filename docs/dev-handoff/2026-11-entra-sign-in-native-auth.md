# Dev handoff — Entra External ID native sign-in (ADR-0022)

- **Branch:** `entra-sign-in`
- **Status:** Code complete, build green, **1233/1233 tests passing** (`fastlane test`, 2 Nov 2026).
- **ADR:** [`docs/adr/0022-entra-external-id-native-authentication.md`](../adr/0022-entra-external-id-native-authentication.md) — read this first; it's the authoritative decision record. This handoff summarises *what was built* and *what's left for the team to do*.
- **Related ADR updated:** [`docs/adr/0009-offline-biometric-local-reentry.md`](../adr/0009-offline-biometric-local-reentry.md) — addendum added recording that §7's standing obligation is now partially answered.

## 1. What changed, in plain terms

The Sign In screen went from a **UI-only demo** (tapping "Sign in" always succeeded, regardless of what was typed) to **real email + password authentication** against **Microsoft Entra External ID** (a CIAM tenant), using Microsoft's **MSAL Native Authentication** SDK — no in-app browser, no redirect. Alongside that:

- Sign-in now calls out to Entra, handles loading/error states, and clears the password from memory after every attempt.
- A **7-day offline grace period** lets a previously-verified user keep using the app without connectivity; past that, they're bounced back to Sign In.
- A background silent-session check runs at launch and on returning to the foreground, so an expired/revoked session is caught without blocking the UI.
- **Settings → Sign out is now real** — it actually signs out of Entra and clears all local session state, rather than just closing a dialog.
- Email format validation was added (previously presence-only).

## 2. New files (all under `record-catch/Core/Security/Auth/`)

| File | Purpose |
|---|---|
| `Authenticating.swift` | The seam protocol (`signIn`, `restoreSession`, `signOut`, `hasCachedAccount`) plus `AuthenticatedAccount`, `SignInOutcome`, `RestoreSessionOutcome`. Everything else in the app depends only on this — no other type imports `MSAL`. |
| `MSALNativeAuthenticator.swift` | The one real, MSAL-backed implementation. Ported from the sibling `entra-id-poc` repo. Maps every credential-revealing MSAL failure to one generic `.invalidCredentials` outcome (security-critical, 100%-covered). Also contains `NotConfiguredAuthenticator` (used when `EntraConfiguration` can't resolve) and the `.make(connectivityMonitor:)` factory. |
| `EntraConfiguration.swift` | Reads/validates `ENTRA_CLIENT_ID` (GUID-shaped) and `ENTRA_TENANT_SUBDOMAIN` (hostname-label-shaped) from the `MMOCRAppConfig` Info.plist dictionary (ADR-0020). Throws `.notConfigured` if either is missing/malformed — **no fallback to another tenant**. |
| `FakeAuthenticator.swift` | In-memory test/preview double, plus `UITestStubAuthenticator` — the `-uiTestAuthStub` seam XCUITests use so they never touch a real Entra tenant. Reserved stub emails: `invalid@example.com` → invalid credentials, `offline@example.com` → network error, `slow@example.com` → succeeds after a short delay. |
| `OfflineAccessPolicy.swift` | Pure, stateless 7-day grace-period decision (`OfflineAccessPolicy.current`). No I/O — trivially unit-tested. |
| `SessionVerificationStore.swift` | Keychain-backed store for *when* the session was last verified online — **never a token**. `KeychainSessionVerificationStore` (real) / `InMemorySessionVerificationStore` (tests). |

## 3. Changed files — what and why

| File | What changed |
|---|---|
| `App/record_catchApp.swift` | `sessionCoordinator` now built in `init()` (not a `@State` default) so it shares the *same* `connectivityMonitor`/`NWPathMonitor` instance as the authenticator. Added a `.task` that runs a silent background session check at launch. Foreground re-check now also runs from the app-lock phase, not just home. `SignInView` is now built via `sessionCoordinator.makeSignInView()`. `RootTabView` is given `onSignOut: sessionCoordinator.handleSignOut`. |
| `Core/Security/RootSessionCoordinator.swift` | Composition root, substantially extended: takes `authenticator`, `verificationStore`, `connectivityMonitor`, `offlineAccessPolicy`. New `verifySessionInBackground()`, `handleSignOut()`, `makeSignInView()`. `handleSignIn()` now takes the `AuthenticatedAccount` returned by a real sign-in. `computePhase` → `computeLocalPhase`, now also consults connectivity + the offline policy. `.make(...)` picks `MSALNativeAuthenticator` normally, or the UI-test stub for any `-uiTest*` launch. |
| `Features/SignIn/SignInViewModel.swift` | No longer a UI-only stub. Takes an `Authenticating` (no default — see note below). `submit()` is now `async`, guards against double-submission (`isSubmitting`), calls the authenticator, clears the password after every attempt, and maps the outcome to a `formError` (`invalidCredentials` / `network` / `serviceUnavailable` / `notConfigured`). |
| `Features/SignIn/SignInView.swift` | Takes `authenticator` in its initialiser (no default). Button shows a loading spinner (`isSubmitting`) and VoiceOver-announces "Signing in". `@AccessibilityFocusState` moves VoiceOver focus to the error summary / field in error after a failed submit (WCAG 2.2 AA — errors must be perceivable and locatable). |
| `Features/SignIn/Logic/SignInValidation.swift` | Added `normalisedEmail()` (trim + lowercase) and a practical (non-regex, non-RFC-5322) email format check. `.missingFields` renamed `.missingOrInvalidFields`; new `SignInFormError` cases `.network`, `.serviceUnavailable`, `.notConfigured` (all map to the same provisional `signIn.error.service` copy for now). |
| `Features/Settings/SettingsViewModel.swift` | Takes `onSignOut: () -> Void`. `confirmSignOut()` now calls it instead of being a documented no-op. |
| `Features/Settings/Views/SettingsView.swift` | Forwards an `onSignOut` closure through to the view model. |
| `Features/TabBar/RootTabView.swift` | Forwards `onSignOut` down to the Settings tab. |
| `Features/Common/Components/Form/PrimaryButton.swift` | New `isLoading` / `loadingAccessibilityLabel` / `accessibilityHintText` parameters — generic enough to reuse for any future async-submit button, not just Sign In. |
| `Resources/Localizable.xcstrings` | 4 new keys added via `scripts/add_entra_signin_strings.py` (see §5). |
| `record-catch.xcodeproj/project.pbxproj` | Added the `microsoft-authentication-library-for-objc` SPM package, **pinned to exact version 2.17.0**, and linked the `MSAL` product to the `record-catch` target. |
| `Config/app-config.schema.json` | Added `ENTRA_CLIENT_ID` and `ENTRA_TENANT_SUBDOMAIN` keys — both `required: false`, both `log: true` (neither is a secret). |
| `Config/Local.xcconfig.example` | Added commented-out example lines for the two keys above. |
| `docs/adr/0009-offline-biometric-local-reentry.md` | Addendum noting §7 is now partially answered by ADR-0022. |

**Test files updated to match:** `RootSessionCoordinatorTests.swift`, `SettingsViewModelTests.swift`, `SignInValidationTests.swift`, `SignInViewModelTests.swift`. Two new test files were added: `EntraConfigurationTests.swift`, `OfflineAccessPolicyTests.swift`.

### A deliberate Swift quirk worth knowing about

`SignInView.init` and `SignInViewModel.init` take `authenticator` **with no default value**. This is intentional, not an oversight: Swift default-argument expressions aren't actor-isolated, so a `@MainActor`-isolated type like `FakeAuthenticator` can't be used as one. Every call site (app root, previews, tests) supplies an authenticator explicitly instead.

## 4. What's left for the team to do

Nothing further is needed in Swift code. What remains is **configuration and tenant setup**, which ADR-0022's "Ownership" section explicitly assigns to the **Entra tenant team / DevOps**, not iOS development:

### 4.1 Get a real Entra tenant + app registration (Entra tenant team)

- A **Microsoft Entra External ID (CIAM)** tenant (`<subdomain>.ciamlogin.com`) — a plain workforce tenant (`login.microsoftonline.com`) does **not** support native authentication.
- An app registration in that tenant with **Native Authentication** enabled, challenge type = password only (no MFA/OTP — this app doesn't support that step yet).
- This gives you two values: a **client ID** (a GUID) and the **tenant subdomain**.

### 4.2 Wire those values in per release stage (DevOps)

Set these as **GitHub Environment variables** (not secrets — they're non-sensitive) on each stage's Environment, alongside the existing `CR_APP_CFG_API_BASE_URL`:

```
CR_APP_CFG_ENTRA_CLIENT_ID = <application-client-id-guid>
CR_APP_CFG_ENTRA_TENANT_SUBDOMAIN = <tenant-subdomain>
```

These are allow-listed in `Config/app-config.schema.json` and get written into the `MMOCRAppConfig` Info.plist dictionary by the existing build-time injection mechanism (ADR-0020) — no pipeline changes needed, just populate the values. Until they're set, `EntraConfiguration` throws `.notConfigured` and the app shows the "service unavailable" sign-in error — this is the expected, safe default, not a bug.

### 4.3 Local development setup (any iOS developer, to test real sign-in locally)

1. Copy `Config/Local.xcconfig.example` → `Config/Local.xcconfig` (this file is git-ignored — **never commit it**).
2. Uncomment and fill in the two lines:
   ```
   CR_APP_CFG_ENTRA_CLIENT_ID = <application-client-id-guid>
   CR_APP_CFG_ENTRA_TENANT_SUBDOMAIN = <tenant-subdomain>
   ```
3. Build and run as normal (Debug configuration). No other setup is required — the SPM package is already resolved as part of the project, no Keychain entitlement was needed, and no URL scheme/redirect URI is needed (native auth doesn't use a browser redirect).
4. Leaving `Config/Local.xcconfig` absent (or those two lines commented out) is also fine — you'll exercise the "not configured" path instead of a real round-trip, which is useful for UI work that doesn't need a live tenant.

### 4.4 Once real per-stage values exist

- Flip `ENTRA_CLIENT_ID` / `ENTRA_TENANT_SUBDOMAIN` from `required: false` to `required: true` in `Config/app-config.schema.json` for the stages that have real values (tracked as a standing obligation in ADR-0022).

### 4.5 Content review (Product/Content design)

- `signIn.error.service` is a **single provisional message** covering three different outcomes (no connectivity, any other Entra/MSAL failure, and "not configured"). It's flagged `NEEDS CONTENT REVIEW` in the string catalog comment and in `docs/design-specs/sign-in.md`. Product/content design should confirm whether these should ever be split into more specific messages.
- Welsh (`cy`) translations for all 4 new strings are machine-drafted placeholders marked `needs_review` in the string catalog — a Welsh speaker should review them before release.

### 4.6 Standing obligations carried forward (not in scope for this piece of work)

Recorded in ADR-0022's Consequences section, for awareness only:

1. **Self-service password reset** ("Forgotten your password?" stays an inert link) — separate ticket.
2. **Wrap the biometric re-entry secret around the real Entra refresh token** instead of today's opaque locally-generated value — partially addressed by the new 7-day offline grace period, but the re-entry secret itself is unchanged.
3. **A protected backend API access-token scope** — not attempted; the PoC's self-referencing scope approach failed and wasn't repeated. Test this in isolation before building anything on top of it, once a backend scope exists.

## 5. New localisation keys

Added via `scripts/add_entra_signin_strings.py` (idempotent — safe to re-run, skips existing keys):

| Key | English | Used for |
|---|---|---|
| `signIn.error.email.invalid` | "Enter a valid email address" | Inline error when email is non-empty but badly formatted |
| `signIn.error.service` | "Sorry, there is a problem signing in. Try again later" | Provisional, covers network/service/not-configured outcomes — **needs content review** |
| `signIn.a11y.signingIn` | "Signing in" | VoiceOver label while the Sign In button is loading |
| `signIn.a11y.hint` | "Submits your sign in details" | Accessibility hint for the Sign In button |

## 6. Verifying it works

- **Automated:** `fastlane test` — currently 1233/1233 passing, including the new `EntraConfigurationTests` and `OfflineAccessPolicyTests`.
- **Manual, without a real tenant:** run the app with no `Config/Local.xcconfig` Entra values set — confirm Sign In shows the generic service-unavailable error on submit, and that it never crashes or silently "succeeds".
- **Manual, with a real tenant:** fill in `Config/Local.xcconfig` (§4.3), run, and sign in with a real Entra External ID test account. Confirm: correct password signs in; wrong password shows the generic "invalid credentials" message (not a Microsoft-specific one); turning on Airplane Mode before submitting shows the network message; Settings → Sign out returns you to the Sign In screen and a subsequent app relaunch does **not** silently reopen the session.
- **Offline grace period:** sign in once online, then go offline and relaunch within 7 days — should fall through to the existing app-lock/home flow. Force the device clock forward past 7 days (or adjust `OfflineAccessPolicy.current` locally for testing) to confirm it falls back to Sign In.
