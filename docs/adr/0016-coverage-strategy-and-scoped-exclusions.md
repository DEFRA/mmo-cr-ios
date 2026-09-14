# ADR 0016 — Coverage strategy: baseline, dead-code removal and scoped exclusions

- Status: Accepted
- Date: 2026-09
- Deciders: iOS engineering
- Context tags: testing, coverage, sonarcloud, governance, native-iOS

## Context

A SonarCloud analysis of `DEFRA_mmo-cr-ios` on 2026-09-10 measured **41.76% overall coverage**
(7,395 lines to cover, 4,307 uncovered) and an **ERROR** quality gate on three conditions:
`new_coverage` 59.6% (needs ≥90%), `new_security_rating` 3 (needs 1) and `new_critical_violations`
4 (needs 0).

Root-causing the 41.76% baseline: **90.6% of uncovered lines are inside SwiftUI `View` bodies and
their subviews**, not business logic. `record-catchTests` is a pure-XCTest unit target — it never
renders a `View`, so a `body` is only "covered" incidentally, via whatever a unit test happens to
construct on the way to testing a view model or helper. `record-catchUITests` *does* exercise real
rendered UI end-to-end, but per ADR-0008 §3 it is **deliberately skipped in the `fastlane test`
CI lane** (`skip_testing: [record-catchUITests]`) — slower and, at the time, flakier — so none of
that coverage currently reaches SonarCloud either. The result is a large, structural view-layer
coverage gap that predates this change and is **not** a regression introduced by any single PR.

This ADR is scoped to a "quick win" PR that cannot and does not attempt to close that whole gap. It
instead: removes genuinely dead code found during the investigation, resolves the
`new_critical_violations` and `new_security_rating` conditions (which are tractable immediately),
and adds a small number of narrowly-justified coverage exclusions — while explicitly declining the
tempting broad fix (excluding all views/components) because that would hide real logic, not just
scaffolding.

## Decision

### 1. Remove confirmed dead code rather than test it

`Features/Common/Views/TripFormDemoView.swift` (109 uncovered lines) and
`TripsOverviewDemoView.swift` (38 uncovered lines) were early component-gallery/demo screens with
**zero remaining call sites** — `HomeView` (ADR-0015) is the production replacement for the
latter, and no screen routes to either. Deleting them (and their stale references in
`Features/Common/README.md` and `ExpandableHelpSection.swift`'s doc comment) removes 147
uncovered lines from the denominator with no loss of real functionality or test coverage — the
single highest-leverage coverage action available, and one that requires writing zero new tests.

### 2. Clear all 24 `swift:S1186` critical violations with genuine explanations

Every flagged empty function/closure body (router `init()`s, inert Settings/ManageAccount "Change"
link seams, no-op default closures on `PaginationControls`/`SubmissionsTable`/`AppLockViewModel`/
`SignInView`, etc.) already had a *reason* to be empty — a deliberate no-op seam pending a future
destination (mirroring the existing pattern in `SettingsViewModel`/`ManageAccountViewModel`), or a
default value with no per-instance state to initialise. Each now carries a short `///`/`//` comment
stating that reason in place, rather than being rewritten to add unwanted behaviour or converted to
`// TODO` filler — this clears `new_critical_violations` without changing any runtime behaviour.

### 3. Accept, not silently weaken, the one Keychain vulnerability finding

`KeychainStore.set(_:account:accessControl:)`'s `else` branch (no `accessControl` supplied) sets
`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`, which SonarCloud flags as a reviewable security
hotspot. Investigation found the **only** caller passing `accessControl: nil` is
`KeychainLocalSessionStore.beginSession()`, storing a single non-secret sentinel byte that must be
readable *before* any biometric prompt (it is what decides whether to *offer* biometric re-entry at
all). The actual secret (`KeychainReentrySecretStore`, ADR-0009) always supplies a
`SecAccessControl` built with `.biometryCurrentSet`, taking the other branch.
`kSecAttrAccessibleWhenUnlockedThisDeviceOnly` is exactly the protection level
`security.instructions.md` mandates for a device-local, non-secret item, and gating the sentinel
itself on biometrics would break the re-entry flow it exists to support. Rather than changing this
code, the finding should be marked **Accepted/Won't Fix in the SonarCloud UI** with that
justification (an accepted issue is excluded from `new_security_rating`); the justification is also
recorded in-line as a code comment so it survives independently of the SonarCloud issue record.

### 4. Narrowly-scoped `sonar.coverage.exclusions` — six files, not a category

`sonar-project.properties` now excludes exactly six files: `SettingsLinkRow`, `LinkButton`,
`NotificationsPlaceholderView`, `ViewFooter`, `TitleText`, and `UITestRootView` — chosen because
each is either a pure, branchless presentation wrapper with no state or logic of its own, a static
placeholder screen, or non-product UI-test launch scaffolding. A blanket `**/*View.swift` or
`Components/**` exclusion was considered and **explicitly rejected**: most views and components in
this app *do* carry real conditional logic, accessibility behaviour or state (e.g.
`ExpandableHelpSection`'s disclosure state, `PaginationControls`' page-item derivation,
`RecordSpeciesWeightsView`'s per-species reveal logic) and must stay counted. This exclusion list is
expected to be reviewed, not grown ad hoc, as the snapshot-testing programme below lands.

### 5. Defer the view-layer coverage backlog to a preview-driven snapshot-testing programme

The 90.6%-of-uncovered-lines view-body gap is a **volume** problem best solved by rendering real
views (via `#Preview`-driven snapshot tests, e.g. exercising `RenderPreview`/snapshot tooling
against existing `#Preview` blocks) rather than by hand-writing thousands of line-level unit
assertions against SwiftUI `body` computed properties, which is both impractical and a poor return
on engineering effort. That programme is **explicitly out of scope for this PR** and will be
proposed and delivered separately.

### 6. Enforce ≥90% on *new* code while ratcheting overall coverage upward

Per DEFRA QA practice, the pragmatic path given the structural baseline gap is to hold new/changed
code to the full **≥90% new-code** bar (already configured via SonarCloud's New Code definition)
while overall coverage improves incrementally as dead code is removed, exclusions are reviewed, and
the snapshot-testing programme lands — rather than blocking all delivery on an immediate jump to
≥90% overall.

## Consequences

- `new_critical_violations` and `new_security_rating` should both clear on this PR's SonarCloud
  re-scan (the Keychain finding requires a manual "Accept" action in the SonarCloud UI in addition
  to the code comment).
- Overall coverage moves up modestly (dead-code removal + six exclusions), but **does not** reach
  the team's ≥90% overall target in this PR — the `new_coverage` gate on this specific PR's new
  lines is expected to be at or near 100%, since no new logic-bearing code was added, only comments,
  deletions and a justified access-control comment.
- **Explicit governance-visible deviation:** the DEFRA testing standard's ≥90% overall coverage
  target (`.github/instructions/testing.instructions.md`) is **not yet met** by this codebase
  (41.76% baseline, expected to rise only slightly here). This is logged as a standing deviation and
  should be raised with the DEFRA Delivery Architecture function
  (`delivery.architecture@defra.gov.uk`), alongside the existing native-iOS architecture exception
  (ADR-0001), until the snapshot-testing programme closes the view-layer gap.
- The six-file exclusion list is a living list scoped to this PR's findings, not a precedent for
  broader exclusion; any future addition should carry the same per-file, logic-free justification.

## References

- ADR-0001 (architecture pattern; pure-helper testability rationale extended here to the
  view-layer coverage discussion).
- ADR-0008 (CI pipeline; `record-catchUITests` skipped in the `fastlane test` lane — the other half
  of the coverage-gap root cause).
- ADR-0009 (offline biometric local re-entry; `KeychainLocalSessionStore` / `ReentrySecretStoring`
  split referenced in the Keychain vulnerability decision above).
- ADR-0015 (Home merged records list; `HomeView` is the production replacement for
  `TripsOverviewDemoView`).
- `.github/instructions/testing.instructions.md` (coverage targets).
- `.github/instructions/security.instructions.md` (Keychain accessibility-level guidance).
