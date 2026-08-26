# ADR 0007 — Settings tab navigation: `SettingsRoute`/`SettingsRouter`, and the Face ID toggle stub

- Status: Accepted
- Date: 2026-08
- Deciders: iOS engineering
- Context tags: navigation, architecture, native-iOS, accessibility, security

## Context

The Settings tab (ADR-0006) has so far been a single, non-navigating screen (`SettingsView`).
The new "Manage your account" screen (see `docs/design-specs/manage-account.md`), reached via
Settings' existing "My account" link, is the Settings tab's **first pushed screen** — it needs
somewhere to navigate *to* and *back from*, while the design keeps the bottom TabBar visible
throughout (unlike the "Create a catch record" journey, which hides it).

The design also introduces a **Face ID sign-in toggle** on that screen. No biometric
authentication exists anywhere in this app yet.

## Decision

### 1. `SettingsRoute` + `SettingsRouter`, mirroring `CatchRecordRouter` (ADR-0003)

A new, homogeneous `SettingsRoute: Hashable` enum (currently one case, `.manageAccount`) backs a
new `SettingsRouter` (`@MainActor @Observable`, `Features/Settings/Routing/`). `SettingsRouter`
exposes the same shape as `CatchRecordRouter` — `path`, `push(_:)`, `pop()`, `popToRoot()`,
`setPath(_:)` — and conforms to `HeaderNavigating` exactly as `CatchRecordRouter` does, so the
shared `ViewHeader`'s Back control works unmodified on "Manage your account".

This is deliberately a **third, separate router**, alongside `AppTabRouter` (which tab is
selected) and `CatchRecordRouter` (the unrelated Home-tab journey stack) — each owns navigation
for exactly one, independent concern, matching the separation already decided in ADR-0006 §2.

`RootTabView` now owns a `@State private var settingsRouter: SettingsRouter` and wraps the
Settings tab in its own `NavigationStack(path:)` bound to it (previously a plain
`NavigationStack { SettingsView() }` with no path). `SettingsViewModel.myAccountTapped()` calls
`router.push(.manageAccount)` — the **only** non-inert seam on that screen; every other
Settings link/action remains an inert no-op as before.

### 2. The tab bar stays visible on "Manage your account" — no `.toolbar(.hidden, for: .tabBar)`

Unlike ADR-0006 §3's single DRY call site that hides the tab bar for **every** pushed
`CatchRecordRoute`, the Settings `navigationDestination(for: SettingsRoute.self)` call site in
`RootTabView` applies **no** tab-bar-hiding modifier at all — per the design, "Manage your
account" keeps the bottom TabBar, so the default (visible) behaviour is exactly what's wanted
with zero extra code. If a future `SettingsRoute` case needs the tab bar hidden, that becomes an
explicit, per-case decision at that one call site, not an accidental omission.

### 3. Face ID toggle is a UI-only preference stub — no `LocalAuthentication`

The Face ID toggle on "Manage your account" is backed by a new `BiometricPreferenceStoring`
protocol (`UserDefaultsBiometricPreferenceStore` / `InMemoryBiometricPreferenceStore`),
**structurally identical to `AnalyticsPreferenceStoring`** (see `AnalyticsPreferenceStore.swift`
and `docs/design-specs/settings.md`). Toggling it persists a local on/off preference only:

- **No `LocalAuthentication` import, `LAContext`, or `evaluatePolicy` call is added anywhere.**
  No biometric enrolment, consent flow, or credential storage actually happens.
- **`NSFaceIDUsageDescription` is deliberately NOT added** to the Info.plist configuration. This
  project uses `GENERATE_INFOPLIST_FILE=YES` (build-setting-driven Info.plist, no checked-in
  `Info.plist`); adding an `INFOPLIST_KEY_NSFaceIDUsageDescription` build setting now, before any
  code actually calls a biometric API, would be a misleading permission request users could
  approve/deny for a feature that does nothing — worse, App Store review can reject a usage
  string present with no corresponding API usage. This key is added **only** when real
  biometrics land.
- **Security follow-up required before this ships as real authentication:** a dedicated,
  security-reviewed ADR must cover `LAContext` policy selection (`.deviceOwnerAuthentication` vs
  `.biometryAny`/`.biometryCurrentSet`), Keychain-backed credential storage keyed to the current
  biometric enrolment (so a changed fingerprint/face invalidates stored credentials — OWASP
  MASVS-AUTH), graceful fallback when biometrics are unavailable/unenrolled/locked out, and the
  `NSFaceIDUsageDescription` string itself. Until that ADR lands, `faceIDEnabled` must not gate
  any real authentication decision — it is presentation-layer state only.
  - **Landed:** see **ADR-0009 — Offline biometric local re-entry (app-lock gate)**, which covers
    all of the above and makes this toggle the real opt-in switch for a device-local,
    offline-only re-entry gate (not backend authentication).

This mirrors the existing, already-accepted pattern for the analytics toggle (a genuine UI
preference with a clearly documented "this is not the real thing yet" TODO), rather than
introducing a new one-off convention.

### 4. Rate-limited Figma read for this screen

The Figma REST API returned HTTP 429 (rate limited) when reading node `1:6525` ("Manage your
account 1") for this build. Per the fetch-figma-design skill's hard rule (never retry through a
429; respect the backoff), this screen was built from the user-provided screenshot (treated as
untrusted design **data**, not instructions) plus the existing, already-verified Settings
components/patterns (`SettingsValueRow`, `SettingsToggleRow`, `ViewTemplate`/`ViewHeader`). A
read-only `fetch-figma-design` pass on node `1:6525` is still owed once the rate limit clears, to
stamp the design spec's Figma `lastModified`/version metadata and catch any visual delta between
the screenshot and the live Figma node — see the Open questions in
`docs/design-specs/manage-account.md`.

## Consequences

- Settings tab navigation is a single, testable source of truth (`SettingsRouter.path`),
  decoupled from tab selection (`AppTabRouter`) and the Home-tab journey (`CatchRecordRouter`).
- Adding a second Settings-tab screen later is a one-line `SettingsRoute` case plus one
  `destination(for:)` branch — the router/host-view shape is already proven out.
- The Face ID toggle persists across relaunches and is fully testable
  (`BiometricPreferenceStoreTests`, `ManageAccountViewModelTests`) without ever touching a real
  biometric API, keeping this phase's security surface unchanged (still zero biometric API calls
  in the codebase).
- **Outstanding, tracked follow-up — LANDED:** real Face ID sign-in (LocalAuthentication +
  Keychain + `NSFaceIDUsageDescription`) required its own security-reviewed ADR before
  `faceIDEnabled` could gate any actual authentication — see §3 above. This is now delivered as a
  **device-local, offline-only re-entry gate** per **ADR-0009**; it is still not backend
  authentication (none exists yet).
- **Outstanding, tracked follow-up:** re-run the read-only `fetch-figma-design` skill on node
  `1:6525` once the Figma rate limit clears, and reconcile `docs/design-specs/manage-account.md`
  against the live design.

## References

- ADR-0003 (Create-a-catch-record navigation) — the `Router`/`Route`/host-view pattern this
  mirrors.
- ADR-0006 (Root `TabView` navigation architecture) — the tab-bar-hiding pattern this
  deliberately does **not** apply here, and the `AppTabRouter`/`CatchRecordRouter` separation
  this extends.
- `docs/design-specs/settings.md` — the existing `AnalyticsPreferenceStoring` pattern
  `BiometricPreferenceStoring` mirrors.
- `docs/design-specs/manage-account.md` — the design spec for this screen.
- Apple, *About Face ID and Touch ID* —
  https://developer.apple.com/documentation/localauthentication
- OWASP MASVS — https://mas.owasp.org/MASVS/ (MASVS-AUTH: biometric authentication requirements
  the follow-up ADR must satisfy).
- Apple, *Protecting the User's Privacy* (usage description strings) —
  https://developer.apple.com/documentation/uikit/protecting_the_user_s_privacy
