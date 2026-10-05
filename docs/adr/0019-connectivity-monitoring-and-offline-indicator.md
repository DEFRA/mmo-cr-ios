# ADR 0019 — Connectivity monitoring and the offline status indicator

- Status: Accepted
- Date: 2026-10
- Deciders: iOS engineering
- Context tags: offline-first, accessibility, native-iOS, networking

## Context

The app is required to be offline-first (copilot-instructions.md §3, DEFRA mobile standards): a
field worker recording a catch at sea routinely has no connectivity, and the app must remain
usable and tell the user plainly when it is operating offline. Before this change, there was **no**
connectivity-monitoring layer at all in the codebase (`NWPathMonitor`, `Reachability`, `isOnline`
etc. did not exist anywhere) — every screen silently assumed a network might or might not be there,
with no user-visible signal either way.

The design brief (a Figma-style mock, captured in `docs/design-specs/offline-banner.md`) specifies a
red **"Offline"** tag plus an explanatory message, rendered directly under the GOV.UK header, with a
separator below it — visible only while offline, absent entirely while online.

## Decision

### 1. `ConnectivityMonitoring` protocol seam, not a direct `NWPathMonitor` dependency

`Core/Networking/ConnectivityMonitoring.swift` defines:

```swift
@MainActor
protocol ConnectivityMonitoring: AnyObject {
    var isOnline: Bool { get }
}
```

with a `StubConnectivityMonitor` test/preview double and a `\.connectivityMonitor` environment key
(mirroring the existing `HeaderNavigating`/`\.headerNavigator` seam in
`Features/Common/Views/HeaderNavigating.swift`, rather than `.environment(_:)` on a concrete type,
because the real and stub implementations are different concrete types). This lets `OfflineBanner`
be previewed and unit-tested without a real `NWPathMonitor`, and lets UI tests force a deterministic
offline state via a `-uiTestOffline` launch argument instead of depending on Airplane Mode or
simulator network conditioning.

The environment default is `nil` (not a constructed stub instance) specifically to avoid a
cross-actor-isolation problem: `EnvironmentKey.defaultValue` is a nonisolated static requirement, and
constructing a `@MainActor`-isolated `@Observable` default value from it hits Swift's actor-isolation
checker even via a `nonisolated init` (the `@Observable` macro's synthesized accessors remain
actor-isolated). `nil` carries no such requirement; `OfflineBanner` treats an absent monitor as
**online** (renders nothing), so any context that forgets to configure one fails safe rather than
spuriously showing the banner.

### 2. `NWPathMonitor` via its native `AsyncSequence`, not `pathUpdateHandler`

This app's deployment floor is **iOS 18.0** (`IPHONEOS_DEPLOYMENT_TARGET = 18.0` on every target;
verified directly against `project.pbxproj`, not assumed from documentation — the repository's own
instruction files incorrectly stated "iOS 16" in multiple places at the time of this change and have
been corrected alongside it). `NWPathMonitor`'s `AsyncSequence` conformance depends on
`NWPathMonitor.Iterator`, documented iOS 17.0+, so it is safely usable here. `for await path in
monitor` is used directly from a `Task` owned by the `@MainActor`-isolated
`NetworkConnectivityMonitor`, avoiding the `DispatchQueue` + `pathUpdateHandler` + manual
`Task { @MainActor in … }` trampoline an iOS 16-floor implementation would need, and with it the
off-main-actor data-race hazard that pattern carries.

`isOnline` is seeded synchronously from the path source's current status at `init`, so the first
rendered frame is already correct (no "flash of offline" while the first async iteration is
awaited).

### 3. `PathStatusSource` test seam around the real `NWPathMonitor`

`NWPath` has no public initialiser, so a real `NWPath` cannot be constructed in a test. A thin
`PathStatusSource` protocol (exposing only `currentStatus: NWPath.Status` and a
`statusUpdates() -> AsyncStream<NWPath.Status>`) separates `NetworkConnectivityMonitor`'s
status-mapping logic — fully unit tested in `NetworkConnectivityMonitorTests` via a fake source —
from the one piece that is a genuine OS boundary and cannot be meaningfully unit tested:
`NWPathMonitorStatusSource`, a small adapter around the real `NWPathMonitor`. If this file's
coverage cannot reach the project's tiered targets (see ADR-0016), it is the candidate for a scoped
exclusion — not the monitor's own mapping logic, which has none.

### 4. Rendering: `ViewTemplate`-level, pinned, VoiceOver status announcements

- `OfflineBanner` is inserted into `ViewTemplate`'s `VStack(spacing: 0)` directly under
  `ViewHeader()`, **outside** the `ScrollView`, so it stays pinned and visible while the user
  scrolls the page content. Every screen built on `ViewTemplate` inherits it automatically; no
  per-screen opt-in is required.
- **Sign In and App Lock are excluded by construction, not by an opt-out flag.** Neither screen uses
  `ViewTemplate` (`SignInView.swift` and `AppLockView.swift` both predate this change and
  deliberately render a bespoke, no-header layout), so the banner never appears there. This was a
  deliberate product decision (confirmed with the team) rather than an oversight — a pre-sign-in
  screen is not a context where "your record will be saved" is a meaningful message. Verified by
  `OfflineBannerUITests.test_banner_onSignInScreen_isNotShown_evenWhenOffline()`, which forces
  `-uiTestOffline` and asserts the banner is still absent, rather than merely assuming no code path
  touches that screen.
- Renders `EmptyView()` entirely while online — no reserved space, no layout shift beyond the
  banner's own insertion/removal.
- The online→offline and offline→online transitions each post a
  `AccessibilityNotification.Announcement` (WCAG 2.2 **4.1.3 Status Messages**). Going offline posts
  at `.high` speech-announcement priority (important, time-sensitive, should interrupt); coming back
  online posts at `.default` (informational, must not cut the user off mid-sentence). This also
  covers the Understanding document's explicit "removal of status text" case: losing the banner
  silently would convey nothing to a non-sighted user, so the "Back online" announcement makes that
  removal explicit rather than relying on the visual disappearance alone.
- `.accessibilityReduceMotion` is respected: the insert/remove transition is a plain cross-fade
  under Reduce Motion (no slide), and `nil` entirely in that case.

### 5. Recorded design deviation — solid red/white tag

The Figma-supplied design renders a **solid red background with white text** for the "Offline" tag.
This deviates from two existing conventions:

- This app's own status-tag pattern (`SubmissionsTable`'s `statusSubmittedBackground` /
  `statusUnsentBackground` / `statusLateBackground` etc.), which uses **light background, dark
  text**.
- The GOV.UK Design System's own Tag component guidance (as of the Feb 2026 brand refresh), which
  moved tags to lighter backgrounds with darker text specifically because solid dark-background
  tags were found in user research to be mistaken for interactive buttons.

Per the figma-design instructions (`.github/instructions/figma-design.instructions.md` §6), **the
design is followed as supplied and the deviation is recorded here**, rather than silently
overridden to match the existing convention. Accessibility is unaffected: white-on-`errorRed`
(`#FFFFFF` on sRGB 212, 53, 28) computes to **4.85:1**, which passes WCAG 2.2 AA 1.4.3 for normal
text, and the tag is not interactive (no tap target, no button semantics), so the "could be mistaken
for a button" research finding behind the GOV.UK Tag refresh does not directly transfer. This
deviation should be logged with Delivery Architecture
(`delivery.architecture@defra.gov.uk`) per the standard governance process; it is not hidden.

## Consequences

- A single, app-wide `ConnectivityMonitoring` instance is the one source of truth for "is the
  device online" — any future feature needing that signal (e.g. a sync engine) should consume the
  same instance via `\.connectivityMonitor` rather than standing up a second `NWPathMonitor`.
- **This change is presentation-only.** The banner tells the user their record "will be saved and
  sent when you're back online". The *saved* half is already true today (SwiftData local drafts,
  ADR-0014). The *sent* half is **deferred**: there is no offline mutation queue, no
  send-on-reconnect, and no conflict resolution at the time of this decision. This is accepted
  because the app is currently local-first with no live catch-record submission backend, so the
  copy describes the intended end-state behaviour without misleading any current user.
  **Follow-up required before the app submits real catch records to a live backend:** implement the
  offline queue + flush-on-reconnect path, and revisit this copy if the eventual behaviour differs.
  `NetworkConnectivityMonitor` is deliberately shaped as a reusable seam precisely so that future
  sync engine can observe the same connectivity signal instead of duplicating it.
- `.satisfied` means "a network path exists", not "a specific backend is reachable" — a captive
  portal or a down server still reports "online" here. This is an accepted limitation for a
  presentation-only indicator; a true reachability check against a specific endpoint is out of
  scope for this change and would be a separate, deliberate decision if ever needed.
- The `.github` instruction files' iOS version claims were corrected from "iOS 16" to the verified
  **iOS 18.0** actual deployment target as part of this change (see the change summary), so future
  agents reading them are not misled into unnecessary `#available` guards or an iOS 16-floor
  `NWPathMonitor` implementation.
