# Design Spec — Offline connectivity banner (shared `ViewTemplate` component)

**Last read:** 5 October 2026. **Source:** a user-supplied screenshot (no Figma URL/node provided —
the `fetch-figma-design` skill was not used for this screen). The screenshot shows a device status
bar + GOV.UK header, then, directly below the blue header bar: a solid-red **"Offline"** tag beside
the message *"You can still record your catch. Your record will be saved and sent when you're back
online."*, with a thin horizontal rule beneath. No design spec previously existed for this component.

Feature: app-wide offline connectivity indicator for the DEFRA / MMO Catch Recording iOS app. See
ADR-0019 for the full architectural decision (connectivity monitoring approach, iOS-version
rationale, and the recorded design deviations below).

## Layout (inside `ViewTemplate`, pinned below `ViewHeader`)

`OfflineBanner` is rendered by `ViewTemplate` directly under `ViewHeader()`, **outside** the
`ScrollView` — i.e. pinned, not part of the scrollable page content. Renders `EmptyView()` entirely
while the device is online: no reserved space, no layout shift beyond its own insertion/removal.
While offline, top to bottom:

1. **Row** (`HStack`, top-aligned): a solid-red **"Offline"** tag, then the message, filling the
   remaining width and wrapping onto multiple lines without truncation
   (`.fixedSize(horizontal: false, vertical: true)`).
2. **Divider** — a 1pt `AppColors.divider`-coloured rule spanning the full width, directly below the
   row.

Both the row and the divider sit on `AppColors.background` (white), matching the rest of the page
below the blue header.

## Tokens used

| Element | Token | Value |
|---|---|---|
| Tag background | `AppColors.statusOfflineBackground` | `AppColors.errorRed` (sRGB 0.831, 0.208, 0.110) |
| Tag text | `AppColors.statusOfflineText` | `Color.white` |
| Tag / message font | `AppTypography.bodySmall` (tag: `.weight(.bold)`) | 16pt, Dynamic Type-capable |
| Message text colour | `AppColors.textPrimary` | Black |
| Divider | `AppColors.divider` | sRGB 0.82, 0.82, 0.82 |
| Spacing | `AppSpacing.medium` / `.small` / `.xSmall` | 16 / 8 / 4 |

No raw hex or fixed point sizes are used outside these existing design-system tokens.

## States

- **Online** — nothing rendered. This is the default/majority state and is the explicit acceptance
  criterion: "it is not shown at all if the app is online."
- **Offline** — tag + message + divider, as above, with a status-message VoiceOver announcement
  posted on the transition into this state (see Accessibility below).
- **Transition back to online** — the banner is removed (cross-fade, or instant under Reduce
  Motion) and a second VoiceOver announcement explicitly conveys "Back online", since the mere
  disappearance of the banner would otherwise be silent to a non-sighted user.

There is no loading or error state for this component: `ConnectivityMonitoring.isOnline` is always
either `true` or `false` from the first rendered frame (seeded synchronously from the path monitor's
current status at construction — see ADR-0019 §2).

## Accessibility

- The banner is one combined accessibility element: `.accessibilityElement(children: .combine)` with
  an explicit label `"Offline, <message>"` (built by the pure, unit-tested
  `OfflineBanner.accessibilityLabel(tag:message:)`), so VoiceOver reads it as a single unit rather
  than the tag and message separately. The tag's own text is `.accessibilityHidden(true)` to avoid
  it being read twice.
- WCAG 2.2 **4.1.3 Status Messages**: the online↔offline transition posts an
  `AccessibilityNotification.Announcement` each way (`.high` priority going offline, `.default`
  coming back online) — see ADR-0019 §4 for the full rationale, including the "removal of status
  text" case.
- Contrast: white text (`#FFFFFF`) on `errorRed` (sRGB 212, 53, 28 / `#D4351C`) computes to
  **4.85:1**, passing WCAG 2.2 AA 1.4.3 (≥4.5:1 for normal text). Calculation: relative luminance of
  white = 1.0; relative luminance of `#D4351C` ≈ 0.137; contrast ratio = (1.0 + 0.05) / (0.137 +
  0.05) ≈ 4.85.
- Meaning is not conveyed by colour alone (WCAG 1.4.1): the word "Offline" and the full explanatory
  message both carry the information; the tag's colour is reinforcement, not the sole signal.
- Dynamic Type: both the tag and message use `AppTypography.bodySmall` (`Font.system(size:)`,
  Dynamic-Type-scalable); the message has no fixed width/height and wraps freely, verified visually
  at the largest accessibility text sizes.
- `@Environment(\.accessibilityReduceMotion)` is respected for the insertion/removal transition.
- No tap target: the banner is not interactive (per GOV.UK Tag guidance — tags indicate status and
  must never be made into links/buttons), so the 44×44pt minimum tap-target rule does not apply.

## Deviation register

1. **Solid red/white tag vs this app's own status-tag convention.** `SubmissionsTable`'s existing
   status tags (`statusSubmittedBackground`/`statusUnsentBackground`/`statusLateBackground` etc.)
   all use a **light background with dark text**. This component instead uses a **solid dark-red
   background with white text**, matching the supplied design exactly. **Followed as designed, not
   silently normalised** — see ADR-0019 §5 for the full rationale and the accessibility check that
   confirms this is safe to do (4.85:1 contrast; the tag is non-interactive, which was the concern
   behind the GOV.UK Design System's own move away from solid-background tags).
2. **No Figma source.** This spec was captured from a user-supplied screenshot rather than a fetched
   Figma node, per the figma-design instructions' "no design provided → build from the spec"
   fallback. If a Figma source is later supplied for this screen, re-fetch and reconcile against
   this spec rather than assuming it is already exact.

Both deviations should be logged with Delivery Architecture (`delivery.architecture@defra.gov.uk`)
for governance visibility, per the standard process — they are recorded here, not hidden.

## Explicitly excluded screens

Sign In and App Lock **do not** show this banner, because neither uses `ViewTemplate` (both
predate this component and intentionally render a bespoke, no-header layout — see
`SignInView.swift`/`AppLockView.swift`). This was confirmed as the intended behaviour (not merely
assumed) and is locked in by
`OfflineBannerUITests.test_banner_onSignInScreen_isNotShown_evenWhenOffline()`, which forces offline
and asserts the banner is still absent on that screen.

## Out of scope (tracked, not forgotten)

This component is **presentation-only**. There is no offline mutation queue or send-on-reconnect
sync engine yet — see ADR-0019 "Consequences" for the explicit follow-up this implies before the
app submits real catch records to a live backend.
