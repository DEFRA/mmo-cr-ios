# ADR 0003 — Navigation for the "Create a catch record" journey

- Status: Accepted
- Date: 2026-07
- Deciders: iOS engineering
- Context tags: navigation, architecture, native-iOS

## Context

Part 1 of the "Create a catch record" journey introduces the app's **first real screen-to-screen
navigation** (Draft action → Select vessel → Did your trip start and finish today? → next step).
Until now, `HomeView`'s "Create a new catch record" button and the submissions table's date links
were inert (see `HomeView.swift`). This journey is open-ended — more steps will be appended in
later phases — and must remain UI-only (no persistence, no networking) per this phase's scope,
while staying consistent with the `@Observable @MainActor` view model pattern in
[ADR-0001](0001-app-architecture-pattern.md).

## Decision

### 1. A typed route enum, not `NavigationPath`

We introduce `CatchRecordRoute: Hashable`, an enum with one case per screen in the journey:

```swift
enum CatchRecordRoute: Hashable {
    case draftAction(SubmissionRow)
    case selectVessel
    case tripStartedToday(referenceNumber: String)
    case placeholderNextStep
}
```

We deliberately use a **typed, homogeneous array** (`[CatchRecordRoute]`) rather than SwiftUI's
type-erased `NavigationPath`:

- **Testable:** a `[CatchRecordRoute]` can be asserted against directly in unit tests (equality,
  count, associated values) with no runtime type-casting. `NavigationPath` requires `Codable`
  round-tripping or opaque introspection to test, which is brittle and indirect.
- **Homogeneous:** every destination in this journey is a screen we own; there is no need for
  `NavigationPath`'s ability to mix arbitrary `Hashable` types on one stack.
- **Open-ended without extra machinery:** adding a new step is "add an enum case + a
  `navigationDestination` mapping + a screen" — no change to the routing/testing approach.
- **Compile-time exhaustiveness:** the `navigationDestination(for:)` switch is exhaustive over the
  enum, so the compiler flags a missing destination when a new case is added.

### 2. A single `@Observable @MainActor` router owns the path

```swift
@MainActor
@Observable
final class CatchRecordRouter {
    var path: [CatchRecordRoute] = []
    func startFromDraft(_ row: SubmissionRow)
    func startNew()
    func push(_ route: CatchRecordRoute)
    func popToRoot()
}
```

- `CatchRecordRouter` is injected once (via `.environment(_:)`) at the journey's host view and
  bound to a single `NavigationStack(path: $router.path)` with `.navigationDestination(for:
  CatchRecordRoute.self)`.
- Screens/view models never construct `NavigationLink`s directly; they call `router.push(...)`,
  `startFromDraft(...)`, `startNew()` or `popToRoot()`. This keeps navigation decisions (which
  screen comes next) inside testable view models rather than view bodies, mirroring how
  `SignInViewModel` owns presentational state today.
- `popToRoot()` supports the Draft-action "Delete" destructive flow, returning the user to Home
  without walking back screen-by-screen.

### 3. Scope: no persistence, no networking

The router holds only **in-memory navigation state** for the lifetime of the journey. It does not
persist the path, call any API, or write to disk. This is consistent with this phase's UI-only
scope; a future ADR will cover offline-first submission persistence and sync once the journey
reaches an API-backed phase.

### 4. Open for extension

A future step is added by:

1. Adding a new `CatchRecordRoute` case (with any associated values it needs).
2. Adding a `navigationDestination` mapping for it at the host view.
3. Building the screen (View + `@Observable @MainActor` view model + pure validator), following
   the pattern of the three screens this ADR introduces.

No change to `CatchRecordRouter`, `CatchRecordRoute`'s underlying storage, or existing screens is
required.

### 5. Cross-reference: hosting inside the root `TabView` (ADR-0006)

A later ADR ([ADR-0006](0006-tabbar-navigation-architecture.md)) introduces a root `TabView` with
Home/Notifications/Settings tabs. `CatchRecordHostView`, `CatchRecordRouter` and `CatchRecordRoute`
as decided here are **unchanged** by that ADR — only *where* `CatchRecordHostView` is mounted
changes (inside the Home tab, rather than being the app's sole root view), and a single
`.toolbar(.hidden, for: .tabBar)` wrapper is added at this file's `destination(for:)` switch so the
tab bar hides while the journey is in progress. See ADR-0006 for the full rationale.

## Consequences

- Navigation state is a plain, `Equatable`/`Hashable` value, so `CatchRecordRouterTests` can assert
  `router.path == [...]` directly without a hosted `NavigationStack`.
- Every screen depends only on `CatchRecordRouter`, kept thin and mockable in tests by injecting a
  router instance and asserting its resulting `path`.
- Because routes carry the data they need (e.g. `SubmissionRow`, a reference number), destinations
  don't need to reach back into shared/global state to render.
- Standing consideration: as this journey grows, we will re-assess whether path depth/complexity
  warrants splitting into per-sub-journey routers; not needed at 4 steps.

## References

- Apple, *NavigationStack* — https://developer.apple.com/documentation/swiftui/navigationstack
- Apple, *navigationDestination(for:destination:)* —
  https://developer.apple.com/documentation/swiftui/view/navigationdestination(for:destination:)
- GOV.UK Design System, *Radios* — https://design-system.service.gov.uk/components/radios/
- WCAG 2.2 Success Criterion 2.5.8 (Target Size, Minimum) —
  https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum.html
- WCAG 2.2 Success Criterion 2.3.3 (Animation from Interactions) —
  https://www.w3.org/WAI/WCAG22/Understanding/animation-from-interactions.html
- WCAG 2.2 Success Criterion 3.1.2 (Language of Parts) —
  https://www.w3.org/WAI/WCAG22/Understanding/language-of-parts.html
- WCAG 2.2 Success Criterion 3.3.1 (Error Identification) —
  https://www.w3.org/WAI/WCAG22/Understanding/error-identification.html
- WCAG 2.2 Success Criterion 3.3.4 (Error Prevention — Legal, Financial, Data) —
  https://www.w3.org/WAI/WCAG22/Understanding/error-prevention-legal-financial-data.html
- WCAG 2.2 Success Criterion 4.1.3 (Status Messages) —
  https://www.w3.org/WAI/WCAG22/Understanding/status-messages.html
