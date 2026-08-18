# ADR 0006 — Root `TabView` navigation architecture

- Status: Accepted
- Date: 2026-08
- Deciders: iOS engineering
- Context tags: navigation, architecture, native-iOS, accessibility

## Context

The app has grown a second and third top-level destination — a **Notifications** placeholder and a
**Settings** screen (see `docs/design-specs/settings.md`) — that sit alongside the existing
**Home** / "Create a catch record" journey (ADR-0003). The Figma design for Settings shows all
three as a standard iOS bottom **TabBar**: Home, Notifications, Settings. Until now the app has had
a single root view (`CatchRecordHostView`) with no tab-level navigation at all.

This ADR records how the root `TabView` is introduced **without disturbing** the existing,
already-tested "Create a catch record" journey navigation from ADR-0003, and how the tab bar is
hidden while that journey is in progress (its screens are a full-screen, header-driven flow with
no tab chrome in the design).

## Decision

### 1. A root `TabView`, one `NavigationStack` per tab

```swift
TabView(selection: $router.selection) {
    NavigationStack { CatchRecordHostView's own internal stack }.tag(.home)
    NavigationStack { NotificationsPlaceholderView() }.tag(.notifications)
    NavigationStack { SettingsView() }.tag(.settings)
}
```

Each tab owns **its own** `NavigationStack`, per
[Apple's `TabView` guidance](https://developer.apple.com/documentation/swiftui/tabview) and the
[HIG's tab bar guidance](https://developer.apple.com/design/human-interface-guidelines/tab-bars) —
switching tabs preserves each stack's navigation state independently, and only one tab's stack is
visible at a time. The Home tab's `NavigationStack` is the one **already owned internally by
`CatchRecordHostView`** (ADR-0003) — it is not duplicated or re-hosted; `RootTabView` simply places
the existing, unmodified `CatchRecordHostView` inside the Home tab item.

### 2. Tab selection is a separate, dedicated, non-View router

`AppTabRouter` (`@MainActor @Observable`, see `Features/TabBar/AppTabRouter.swift`) owns only
`selection: AppTab`, where `AppTab` is `.home | .notifications | .settings`. It is deliberately:

- **A separate type from `CatchRecordRouter`.** `CatchRecordRouter` continues to own only the
  in-journey navigation *within* the Home tab (unchanged from ADR-0003); `AppTabRouter` owns only
  *which tab* is selected. Mixing the two would conflate "which top-level destination" with
  "where am I inside that destination", and would make the already-tested `CatchRecordRouter` API
  and tests need to change for an unrelated concern.
- **Free of any View type**, so it is trivially unit-testable (`AppTabRouterTests`) with no hosted
  `TabView`, and can be seeded synchronously from a UI-test launch argument before the first
  `body` evaluation — mirroring how `CatchRecordRouter`'s `path` is asserted directly in
  `CatchRecordRouterTests`.
- Injected once (via `.environment(_:)`) at the app root, alongside `AppLanguageStore`.

### 3. Hiding the tab bar during the journey — one DRY call site

The "Create a catch record" journey's screens are a full-screen flow with the shared `ViewHeader`
(back link + branding) and **no** tab bar per the design; the tab bar should only be visible on the
Home tab's root (`HomeView`) and disappear the instant the user pushes into the journey, then
reappear when they pop back to `HomeView`.

Rather than adding `.toolbar(.hidden, for: .tabBar)` to each of the 20+ individual
`CatchRecordRoute` destination screens (repetitive, and easy to miss on a newly-added screen), we
apply it **once**, at the single `@ViewBuilder` `destination(for:)` switch inside
`CatchRecordHostView` that already fans out every route to its screen:

```swift
@ViewBuilder
private func destination(for route: CatchRecordRoute) -> some View {
    switch route { /* ...existing 20+ cases... */ }
}
// wrapped once at the call site:
.navigationDestination(for: CatchRecordRoute.self) { route in
    destination(for: route)
        .toolbar(.hidden, for: .tabBar)
}
```

This is DRY (one line covers every current **and future** route — a new `CatchRecordRoute` case
automatically gets the tab bar hidden with no extra work) and keeps `HomeView` (the
`NavigationStack`'s un-pushed root) unaffected, so the tab bar is visible there and hidden for
every pushed destination.

`.toolbar(.hidden, for: .tabBar)` is the
[documented `View.toolbar(_:for:)` modifier](https://developer.apple.com/documentation/swiftui/view/toolbar(_:for:))
available since iOS 16 for the `.tabBar` placement, matching this app's iOS 16+ deployment target.
Apple's own `ToolbarPlacement`/`Visibility` overloads used here have since been superseded by a
newer `toolbarVisibility(_:for:)` API in later SDKs, but the iOS 16-available `.toolbar(_:for:)`
form remains supported and is what this app targets; centralising it at this single call site means
a future migration to `toolbarVisibility(_:for:)` is a one-line change, not a 20-file one.

### 4. Cross-reference to ADR-0003

ADR-0003 is otherwise **unchanged**: `CatchRecordRouter`, `CatchRecordRoute` and
`CatchRecordHostView`'s internal `NavigationStack`/routing continue exactly as decided there. This
ADR only changes *where* `CatchRecordHostView` is mounted (inside the Home tab of a root `TabView`,
instead of being the app's sole root view) and adds the single tab-bar-hiding wrapper described
above. A note has been added to ADR-0003 cross-referencing this ADR for that context.

### 5. Minimal Settings/Notifications shells in this phase

`SettingsView` and `NotificationsPlaceholderView` are intentionally minimal in this phase (a
compiling shell and an accessible "coming soon" empty state respectively) — the full Settings
screen content (analytics toggle, account links, "Gear used") from `docs/design-specs/settings.md`
is deferred to a later phase and is out of scope here. Introducing the tab structure now, ahead of
that content, avoids a larger later refactor of the app's root view.

### 6. Deviation: Notifications tab icon

The Figma design's Notifications tab icon is a Material "sms" speech-bubble glyph. We use the SF
Symbol `bell`/`bell.fill` instead — a chat-bubble icon reads as "messages", not "notifications", to
an iOS user and would be a confusing, non-standard icon choice on this platform (see HIG guidance
on using system symbols for common, recognisable meanings). Recorded as a deviation for governance
per `docs/design-specs/settings.md`'s deviation register.

## Consequences

- Tab selection is a single, testable source of truth (`AppTabRouter.selection`), decoupled from
  the journey's own navigation state.
- The tab bar's hide/show behaviour is driven by one call site, so it cannot be forgotten on a
  newly-added `CatchRecordRoute` case.
- `CatchRecordHostView`'s public surface and behaviour are unchanged — existing
  `-uiTestCatchRecord*` launch arguments continue to boot a bare `CatchRecordHostView` with no tab
  bar at all, so `CatchRecordUITests` do not regress.
- Standing consideration: if a future tab needs its own multi-step journey (its own typed route
  enum/router, mirroring `CatchRecordRouter`), the same per-tab-`NavigationStack` pattern already
  supports that without changing `AppTabRouter`.

## References

- Apple, *TabView* — https://developer.apple.com/documentation/swiftui/tabview
- Apple, *View.toolbar(_:for:)* — https://developer.apple.com/documentation/swiftui/view/toolbar(_:for:)
- Apple Human Interface Guidelines, *Tab bars* —
  https://developer.apple.com/design/human-interface-guidelines/tab-bars
- WCAG 2.2 Success Criterion 1.4.3 (Contrast, Minimum) —
  https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html
- WCAG 2.2 Success Criterion 2.5.8 (Target Size, Minimum) —
  https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum.html
- ADR-0003 (Create-a-catch-record navigation) — unchanged, cross-referenced above.
- `docs/design-specs/settings.md` — Figma design spec for Settings + TabBar.
