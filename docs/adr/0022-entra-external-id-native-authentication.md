# ADR 0022 — Entra External ID native authentication (email + password sign-in)

- Status: Accepted
- Date: 2026-11
- Deciders: iOS engineering (security-reviewed)
- Context tags: security, authentication, offline-first, native-iOS, accessibility

## Context

The Sign In screen (`SignInView`/`SignInViewModel`) has never performed real authentication: every
tap of "Sign in" calls `onSignIn()` unconditionally, and the "invalid credentials" state is a
stubbed presentational flag (see `docs/design-specs/sign-in.md`, "UI only" scope). ADR-0009 §7
recorded this as a **standing obligation**: when real backend authentication lands, the local
biometric re-entry design must be revisited.

A proof of concept at a sibling repository (`entra-id-poc`, see its
`TECHNICAL-DOCUMENTATION.md`) investigated **Microsoft Entra External ID** (a CIAM tenant) native
authentication using the MSAL Native Authentication SDK for iOS. It established:

- Native (in-app, no browser) email + password sign-in requires a **Microsoft Entra External ID**
  tenant (`<subdomain>.ciamlogin.com`) with native authentication enabled on the app registration.
  A workforce tenant (`login.microsoftonline.com`) does not support this.
- A self-referencing "protected API" scope on the client's own app registration does not work and
  was abandoned; no protected API integration is attempted by this ADR.
- MSAL's own Keychain cache is the only place tokens should live; the app must never persist a
  token itself.
- Credential failures (wrong password, unknown user, invalid username) must be collapsed to one
  generic message so the sign-in screen cannot be used to enumerate which email addresses have
  accounts.
- Self-service password reset (`ResetPassword*` delegates) exists in MSAL but was not built in the
  PoC; it is comparable in size to the sign-up flow that was built.

This ADR is the catch-record-specific decision that ports the relevant parts of that PoC and
answers ADR-0009 §7, the ticket's acceptance criteria (AC1–AC9, AC12, EC1–EC3, ES1–ES4), and the
product decisions agreed for this phase.

## Decision

### 1. Native authentication via MSAL, pinned to 2.17.0

- The `microsoft-authentication-library-for-objc` Swift package is added via SPM, pinned to the
  **exact** version **2.17.0** (the latest release at the time of writing, 26 Oct 2026). Native Auth
  V2 in 2.17.0 requires explicit sign-in method selection and no longer retains a password supplied
  up front once a method is chosen; the app's adapter resubmits the password when MSAL's
  `passwordRequired` step asks for it again, mirroring the PoC's pattern.
- If 2.17.0's Native Auth V2 behaviour cannot be adapted cleanly, the fallback is **2.16.0** (the
  PoC's pinned version); any such fallback is recorded as an addendum to this ADR.
- MSAL is initialised with `challengeTypes: [.password]` only — no email OTP, since the agreed user
  flow is email + password with MFA disabled (consistent with the PoC's recommendation, §9 "Known
  gaps").
- MSAL's own internal logging has PII disabled; the app's logs never include MSAL's verbose debug
  output.

### 2. One `Authenticating` seam; MSAL is the only adapter behind it

- `Core/Security/Auth/Authenticating.swift` defines a `@MainActor` protocol: `signIn(email:password:)`,
  `signOut()`, `restoreSession()` (silent token refresh) and `hasCachedAccount`.
- `MSALNativeAuthenticator` is the only conforming type backed by real MSAL; `FakeAuthenticator` is
  an in-memory test/preview double. No other code in the app ever imports `MSAL` directly — this
  mirrors the `BiometricAuthenticating`/`KeychainStoring` seam pattern from ADR-0009, keeping the
  third-party SDK isolated and swappable.
- The view model and `RootSessionCoordinator` depend only on `Authenticating`.

### 3. Generic, non-enumerating credential errors (security-critical path)

Every MSAL failure that could reveal whether an account exists — user not found, invalid username,
wrong password, and the "password required again" retry failing — maps to a single
`SignInOutcome.invalidCredentials`, surfaced as the existing `signIn.error.credentials` copy. The
underlying AADSTS error code is logged (public, non-PII) for diagnostics but never shown to the
user or included in any error string the UI renders. This is a 100%-covered path per
`testing.instructions.md`.

Other outcomes are kept distinct because they are not security-sensitive and need different
handling:

- `.network` — no connectivity; sign-in is not attempted (checked via the existing
  `ConnectivityMonitoring`, ADR-0019 — no second `NWPathMonitor` is created).
- `.serviceUnavailable` — any other MSAL/Entra failure (including an MFA/browser-required step the
  app doesn't support, and "too many attempts"/lockout). One provisional message is used for all of
  these for now (see §7); this is intentionally coarse-grained pending product content.
- `.notConfigured` — `EntraConfiguration` placeholders are not yet filled in (see §6).

### 4. Tokens: MSAL Keychain cache only; one new Keychain item for the offline policy

- No access token, ID token or refresh token is ever read into app code beyond what MSAL's adapter
  needs transiently to decide the outcome. `AuthenticatedAccount` carries only a display username
  and MSAL's opaque account identifier, exactly as the PoC did.
- One new, non-token Keychain item is added: `SessionVerificationStore`, holding the UTC timestamp
  of the last successful **online** verification (sign-in or silent refresh). Stored under
  `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`, `ThisDeviceOnly` (never iCloud-synced), matching
  the non-secret "session marker" pattern in ADR-0009 §1 — it is not a credential and does not
  participate in `.biometryCurrentSet` access control.

### 5. Seven-day offline grace period, with a silent check at launch and foreground

Per the product decision for this phase:

- `OfflineAccessPolicy.gracePeriod(days: 7)` is a pure, stateless helper:
  `allowsOfflineAccess(lastVerified:now:) -> Bool`, true only when
  `now.timeIntervalSince(lastVerified) <= 7 * 86_400` and `lastVerified <= now` (a future-dated
  timestamp — e.g. from clock tampering — is treated as *not* verified, never as "still fresh").
- `RootSessionCoordinator` resolves the sign-in/app-lock/home phase using, in order:
  1. No cached MSAL account → `.signIn`.
  2. Online → attempt `restoreSession()` (silent refresh).
     - Success → update `SessionVerificationStore`, then fall through to the existing ADR-0009
       biometric-reentry decision (`BiometricReentryPolicy.offer`) for the app-lock/home choice.
     - Refresh token expired/revoked → clear the local session and re-entry secret → `.signIn`.
  3. Offline → evaluate `OfflineAccessPolicy` against the stored last-verified time.
     - Within the grace period → fall through to the existing ADR-0009 decision (app-lock/home).
     - Past the grace period (or never verified) → `.signIn`.
- The local (session-marker/biometric) decision is never blocked on the network: it runs
  synchronously from stored state first, so cold launch never spins waiting for Entra. The online
  refresh in step 2 runs as a background check and can only *move the user to sign-in* after the
  fact if it discovers the session is no longer valid — it never silently claims success while
  offline (mirrors the PoC's explicit non-goal of "never falsely claim a successful sign-in while
  offline").
- This partially answers ADR-0009 §7: the local session marker is now backed by a real, Entra-issued
  session, not an unconditional stub. Wrapping the refresh token itself inside the
  `.biometryCurrentSet`-gated re-entry secret (rather than today's opaque locally-generated value)
  remains a follow-up, tracked as a standing obligation below.

### 6. Configuration: placeholders now, via `MMOCRAppConfig` (ADR-0020)

- Two new keys are added to `Config/app-config.schema.json`: `ENTRA_CLIENT_ID` and
  `ENTRA_TENANT_SUBDOMAIN`, both `type: "string"`, `log: true` (neither is sensitive — a client ID
  and tenant subdomain are not secrets; this mirrors the PoC's own non-secret treatment of these
  values).
- **Both keys are declared `required: false`** for this phase, since no real tenant/app-registration
  values exist yet. `EntraConfiguration` validates presence and shape (a GUID-shaped client ID, a
  valid hostname-label subdomain) independently of the schema's `required` flag, and surfaces a
  typed `.notConfigured` outcome with no fallback when either is missing/invalid — consistent with
  ADR-0020 §3's "never fall back to another backend". Once real per-stage values are supplied, the
  schema entries should be revisited and (if agreed at that time) promoted to `required: true`.
- No `CFBundleURLTypes`/redirect-URI entry is added. Native authentication does not use a browser
  redirect; MSAL 2.17 logs a harmless console warning about the absent URL scheme, which is
  expected and accepted.
- No Keychain access-group entitlement is added unless the implementation spike shows MSAL's cache
  requires one beyond the app's default access group; this is confirmed during implementation and
  recorded as an addendum if an entitlement proves necessary.

### 7. Content: design-system copy is authoritative; one provisional message is flagged

Per the product decision for this ticket, the existing GOV.UK-style copy in
`docs/design-specs/sign-in.md` is used in preference to the ticket's literal wording (e.g. "Enter
your email address" rather than "Please enter your email address"). One new string,
`signIn.error.email.invalid` ("Enter a valid email address"), is added in the same style. A single
provisional string, `signIn.error.service`, covers every not-otherwise-distinguished failure
(network-adjacent service errors, an MFA/browser-required step, lockout); it is explicitly flagged
in the design spec as **needs content review** before release.

### 8. Forgot Password stays an inert link (AC6 deferred)

"Forgotten your password?" remains a visually-present, non-navigating link in this phase (as it is
today). Self-service password reset is deferred to a separate ticket — per the PoC's own sizing
estimate (§4.6: "a meaningful chunk of work comparable in size to the sign-up flow").

### 9. Real sign-out

Settings → "Sign out" (today an inert confirmation dialog, see `SettingsViewModel.confirmSignOut`)
becomes real: on confirmation, `RootSessionCoordinator.handleSignOut()` calls
`Authenticating.signOut()` (clearing MSAL's cache), clears the ADR-0009 local session marker,
clears the biometric re-entry secret, clears `SessionVerificationStore`, and returns to `.signIn`.
A sign-out that only closed a dialog would otherwise be a security gap once real credentials exist
(no way to change accounts on a shared device).

### 10. UI-test stub, never real Entra in CI

Any `-uiTest*` launch argument (the existing `isUITesting` seam) forces `FakeAuthenticator` in
`RootSessionCoordinator.make(...)`, so no XCUITest run ever depends on network access to a real
Entra tenant. A new `-uiTestAuthStub` flag additionally lets `SignInUITests` select deterministic
outcomes by the email entered (`invalid@…` → invalid credentials, `offline@…` → network error,
`slow@…` → a short delay to exercise the EC1 loading/anti-double-submit state).

## Consequences

- `AuthTokenProviding` (ADR-0018 §5)'s comment pointing to "a future `KeychainStoring`-backed
  provider" is updated to reference this ADR; a bearer-token provider backed by a real Entra access
  token remains a follow-up once a protected backend API scope exists (the PoC's self-referencing
  scope attempt failed and is not repeated here — see Context).
- ADR-0009 gains a cross-reference note: the local session marker is no longer backed by an
  unconditional stub; biometric re-entry now gates access to a real (if currently un-wrapped)
  Entra-issued session, partially answering its §7 standing obligation.
- The sign-in screen's design spec scope changes from "UI only" to "real authentication, UI-test
  stubbed"; its deviation register gains the content-wording note from §7.
- **Standing obligations carried forward:**
  1. Self-service password reset (AC6) — separate ticket.
  2. Wrapping the biometric re-entry secret around the real refresh token, rather than an opaque
     locally-generated value (ADR-0009 §7, now partially addressed by §5 above).
  3. A protected backend API access-token scope, once a backend exists — test it in isolation
     before building anything on top of it (PoC §10.5 step 4).
  4. Revisit `required: false` on the two Entra schema keys once real per-stage values exist.
- **Ownership:** this ADR and the app-side work are iOS Developer work (per
  copilot-instructions.md). Populating the real `CR_APP_CFG_ENTRA_*` Environment variables and any
  Match/entitlement changes are DevOps/Entra-tenant-team work, out of scope for this ADR.

## References

- `entra-id-poc/TECHNICAL-DOCUMENTATION.md` (this repository's sibling PoC), §§2–10.
- Microsoft, *Native authentication in Microsoft Entra External ID* —
  https://learn.microsoft.com/en-us/entra/identity-platform/concept-native-authentication
- `microsoft-authentication-library-for-objc` releases (2.17.0, 2.16.0) —
  https://github.com/AzureAD/microsoft-authentication-library-for-objc/releases
- OWASP MASVS-AUTH / MASVS-STORAGE — https://mas.owasp.org/MASVS/
- ADR-0009 (offline biometric local re-entry, especially §7), ADR-0018 §5 (token seam), ADR-0019
  (single connectivity monitor), ADR-0020 §§2–3 (`MMOCRAppConfig`, never fall back silently).
