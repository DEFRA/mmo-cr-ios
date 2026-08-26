# ADR 0009 — Offline biometric local re-entry (app-lock gate)

- Status: Accepted
- Date: 2026-08
- Deciders: iOS engineering (security-reviewed)
- Context tags: security, authentication, offline-first, native-iOS, accessibility

## Context

ADR-0007 §3 introduced a **UI-only** Face ID preference toggle on "Manage your account" and
explicitly deferred real biometrics behind "a dedicated, security-reviewed ADR" covering
`LAContext` policy selection, Keychain-backed storage keyed to biometric enrolment, graceful
fallback, and the `NSFaceIDUsageDescription` string. This ADR is that follow-up.

There is still **no real backend authentication** in this app (`SignInViewModel`/`SignInView`
call `onSignIn()` unconditionally with no network call, credential, or session object). The
requested feature is explicitly scoped as **local re-entry only**: after a user completes the
(currently stubbed) sign-in once, Face ID/Touch ID should let them re-enter the app on relaunch
or after backgrounding, **fully offline**, instead of redoing the sign-in form. It is **not**
backend credential replay or token refresh — there is no real credential to protect yet.

## Decision

### 1. Two Keychain items — what is actually stored, and why

Because there is no real backend credential, we deliberately store no "authentication secret" of
external value. Instead:

- **Session marker** — a small, non-secret flag meaning "a local session was established on this
  device" (`kSecClassGenericPassword`, `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`, **no**
  access-control/biometric flags). Cheap, always-readable; drives the root-view branch between
  "show sign-in" and "show app-lock/home".
- **Biometric re-entry secret** — a locally generated, random 32-byte value
  (`kSecClassGenericPassword`, `kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly`, access control
  `SecAccessControlCreateWithFlags(nil, kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
  .biometryCurrentSet, &error)`). Retrieving it triggers the Secure Enclave-backed biometric
  prompt; a successful read is the actual re-entry gate. **Its value is opaque and never used for
  anything else** — only its biometric-gated *retrievability* is meaningful. Requires a device
  passcode to exist (implied by `WhenPasscodeSet…`); if none is set, biometric re-entry is not
  offered and the app falls back to the sign-in form.

Neither item is synced to iCloud (`ThisDeviceOnly`), keeping the design fully offline and
device-local, per the DEFRA offline-first and data-at-rest requirements.

### 2. `LAContext` policy — biometrics only, sign-in form as the guaranteed fallback

We use **`.deviceOwnerAuthenticationWithBiometrics`** (biometrics only, no device-passcode
fallback baked into the `LAContext` evaluation) for the pre-flight availability check and the
Settings enable-time enrolment check.

**Alternative considered and rejected:** `.deviceOwnerAuthentication` (adds a device-passcode
fallback inside `evaluatePolicy`). Rejected because the app already provides its own guaranteed
fallback — the existing sign-in form — so a second, device-passcode fallback would duplicate that
path and blur "biometric re-entry" semantics for no benefit.

The **actual security gate is the Keychain-item read** bound to `.biometryCurrentSet`, not a bare
`evaluatePolicy` call. Per OWASP MASTG (MASVS-AUTH, MASTG-TEST-0064), `evaluatePolicy` alone can be
bypassed via runtime instrumentation (e.g. Objection/Frida hooking); a Keychain item protected by a
`SecAccessControl` biometry flag is the MASVS-AUTH-preferred, non-bypassable approach because the
Secure Enclave itself enforces the check to release the item.

### 3. Enrolment-change invalidation — `.biometryCurrentSet`, not `.biometryAny`

We use `kSecAccessControlBiometryCurrentSet` (via `SecAccessControlCreateFlags.biometryCurrentSet`)
so that **adding, removing, or re-enrolling a fingerprint or face automatically invalidates** the
stored re-entry secret (Apple, *SecAccessControlCreateFlags*; OWASP MASTG-TEST-0064). Only the
biometric identities enrolled at the time the secret was provisioned can unlock it. On invalidation
the read fails (`errSecAuthFailed`/similar), the app treats this exactly like "no valid secret" and
forces a full sign-in, re-provisioning the secret afterwards if the preference is still on.
`.biometryAny` was rejected as it survives re-enrolment and is therefore weaker.

### 4. Lock lifecycle

The app-lock screen is shown (when eligible — see §6) on cold launch and whenever the app returns
to the foreground from the background (`scenePhase` transition to `.active` from `.background`).
No auto-unlock timeout/grace period in this phase (kept simple and secure by default); a grace
period can be added later as a product decision without changing this security design.

### 5. `NSFaceIDUsageDescription`

ADR-0007 §3 deliberately omitted `INFOPLIST_KEY_NSFaceIDUsageDescription` because no real
biometric API was called. This ADR **adds it now**, since `LAContext.evaluatePolicy` is genuinely
invoked. Proposed copy (EN): *"We use Face ID to let you sign back in to your catch records
quickly and securely on this device."* Welsh copy is a `needs_review` placeholder pending
translation sign-off, consistent with every other string in this codebase.

### 6. Offline / ATS posture

`LocalAuthentication` and Keychain/Secure Enclave operations are entirely on-device; the re-entry
path makes **zero network calls**, satisfying the user's explicit offline requirement and the
DEFRA offline-first mandate. ATS/TLS posture is unaffected — no new endpoints are introduced.

### 7. Relationship to the still-outstanding real backend auth

This is recorded as a **standing forward obligation**, not a blocker: when real backend
authentication (OAuth2/OIDC, refresh tokens) lands, this local-only design must be revisited so
the Keychain re-entry item wraps a real refresh token (or equivalent) under the same
`.biometryCurrentSet` access-control design, rather than an opaque locally-generated marker. Until
then, this feature must not be mistaken for real authentication — it gates access to local app
state only.

### 8. Settings toggle becomes the real opt-in switch

The existing "Manage your account" Face ID toggle (`BiometricPreferenceStoring`,
`ManageAccountViewModel.faceIDEnabled`) becomes the **real** opt-in switch for this feature.
Turning it **on** now requires a live, successful biometric evaluation before the preference is
persisted and the re-entry secret is provisioned; a failed/unavailable/cancelled check leaves the
preference untouched and surfaces an accessible inline error (never a silent no-op). Turning it
**off** clears the stored re-entry secret and persists the preference as before. This reconciles
ADR-0007 §3 and `docs/design-specs/manage-account.md` deviation #3, both of which flagged this
toggle as **not yet real** pending this ADR.

## Consequences

- A new `Core/Security/` module provides a testable abstraction over `LAContext` and Keychain
  (`BiometricAuthenticating`, `KeychainStoring`, `LocalSessionStoring`, `ReentrySecretStoring`), so
  view models are unit-tested against fakes — no test can exercise real Secure Enclave matching in
  CI or the simulator; a real-device manual QA matrix is required before beta (Face ID device,
  Touch ID device, no-biometrics device, locked-out device, enrolment-changed device, no-passcode
  device).
- `record_catchApp.swift`'s single `isSignedIn` flag becomes a small state machine seeded from the
  session marker + preference + biometry availability, always able to fall back to the existing
  sign-in form — never a dead end.
- The Manage-account Face ID toggle stops being a "does nothing" stub and is reconciled in the same
  change as this ADR (ADR-0007 §3 and the manage-account design spec's deviation #3 are updated to
  point here).
- `NSFaceIDUsageDescription` is added for the first time in this codebase.
- **Standing obligation:** when real backend auth lands, revisit this design per §7.

## References

- Apple, *Logging a User into Your App with Face ID or Touch ID* —
  https://developer.apple.com/documentation/localauthentication/logging-a-user-into-your-app-with-face-id-or-touch-id
- Apple, *LAPolicy* — https://developer.apple.com/documentation/localauthentication/lapolicy
- Apple, *Accessing Keychain Items with Face ID or Touch ID* —
  https://developer.apple.com/documentation/localauthentication/accessing-keychain-items-with-face-id-or-touch-id
- Apple, *SecAccessControlCreateFlags* —
  https://developer.apple.com/documentation/security/secaccesscontrolcreateflags
- Apple, *Restricting Keychain Item Accessibility* —
  https://developer.apple.com/documentation/security/restricting-keychain-item-accessibility
- OWASP MASTG, *Testing Biometric Authentication* (MASVS-AUTH, MASTG-TEST-0064) —
  https://mas.owasp.org/MASTG/tests/ios/MASVS-AUTH/MASTG-TEST-0064/
- OWASP MASVS — https://mas.owasp.org/MASVS/
- ADR-0001 (architecture pattern), ADR-0007 (Settings navigation and the deferred Face ID stub).
