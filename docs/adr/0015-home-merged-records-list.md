# ADR 0015 — Home shows a merged list of local Unsent drafts and server records

- Status: Accepted
- Date: 2026-09
- Deciders: iOS engineering
- Context tags: offline-first, ux, navigation, native-iOS

## Context

Home's trips table (`docs/design-specs/home.md`) previously rendered four hard-coded
`SubmissionRow`s (one of each status) — pure UI-only scaffolding, with no real data source. The
product requirement is that Home's list must contain **both**:

- **Local Unsent records** — persisted, possibly-incomplete drafts (see ADR-0014), which must be
  resumable (or deletable) by tapping the row, even after the app was quit and relaunched.
- **Server records** — Submitted / Amended / Late records. There is no real backend yet (this
  remains a UI-only phase for that side), so these stay a fixed stub, mirroring the ADR-0004
  pattern used throughout the app. What happens after tapping a **Submitted** row is explicitly
  **out of scope** for this ADR — a future ADR will define that journey.

Per the agreed decisions: Unsent means **any local record not yet submitted** (matching Home's
existing status-help copy); the merged list orders **newest first**; and any draft field not yet
captured renders as a placeholder ("—") rather than being omitted or crashing.

## Decision

### 1. `RecordsProviding` — a single seam merging two sources

```swift
protocol RecordsProviding {
    func records() async throws -> [SubmissionRow]
}
```

`MergingRecordsRepository` is the production implementation: it reads local Unsent drafts from
`CatchRecordDraftStoring.allUnsentDrafts()` (ADR-0014) and stub server records from
`ServerRecordsProviding.serverRecords()` (`StubServerRecordsProvider`, a fixed, always-succeeding
fixture set — submitted/amended/late), then merges and orders them. `ServerRecordsProviding` is
kept as its **own** protocol (rather than folded into `RecordsProviding`) so a real backend can
replace only the server half later without touching the local-drafts path — the same seam-per-data-
source shape ADR-0004 established for ports.

### 2. Pure merge/order logic, kept out of the actor-isolated repository

`RecordsMerging` is a free-standing, non-actor-isolated `enum` (mirroring `CatchRecordRouting`)
holding:

- `row(for: UnsentDraftSummary) -> SubmissionRow` — builds a Home row for a persisted draft,
  substituting the shared placeholder (`"—"`) for `vessel`/`tripEndDate` when not yet captured, and
  a fixed `"You"` for `createdBy` (there is no real user identity yet).
- `merge(draftRows:serverRows:) -> [SubmissionRow]` — every row, **newest first** by `sortDate`.

Keeping these as plain static functions (no `@MainActor`, no dependency on
`MergingRecordsRepository`) makes them trivially unit-testable from any context, independent of the
repository's own actor isolation.

### 3. `SubmissionRow` gains ordering/identity metadata, not new displayed content

`SubmissionRow` (`Common/Components/Table/SubmissionsTable.swift`) gains:

- `localID: UUID?` — set for a local Unsent row (so `DraftAction`/resume can look up the persisted
  draft), `nil` for a server row.
- `sortDate: Date` — used only by `RecordsMerging.merge`, defaulted to `.distantPast` for existing
  call sites that don't care about ordering.

Both are **excluded** from `SubmissionRow`'s existing content-based `Equatable`/`Hashable`
conformance, so no existing test/call site needed to change its expectation that two rows with the
same displayed content are equal.

### 4. `HomeViewModel` — explicit loading/empty/error states, never an indefinite spinner

```swift
@Observable @MainActor final class HomeViewModel {
    enum LoadState { case loading, loaded, empty, failed }
    private(set) var rows: [SubmissionRow] = []
    private(set) var loadState: LoadState = .loading
    func load() async { ... }
}
```

`HomeView` calls `load()` in `.task` and again whenever the Create-a-catch-record journey stack
collapses back to Home (`.onChange(of: router.path)`, guarded to `newPath.isEmpty`), so a resumed
draft that was saved further, submitted, or deleted is reflected without requiring an app
relaunch. Per the accessibility instructions, every state has an explicit, non-spinner-forever
presentation: a labelled loading row, a plain "no records yet" empty state, or an accessible error
banner (icon + text + colour, never colour alone) with a retry button that calls `load()` again.
Local Unsent drafts are always available offline-first regardless of the stub server call's
outcome — `RecordsLoadError.unavailable` is only raised if the local draft store itself fails,
which should not normally happen.

### 5. Scope: still stubbed server side, no real submitted-record journey

`StubServerRecordsProvider`'s fixtures are unchanged in shape from the original UI-only mock (3
fixed rows, "20 Nov 2020" / ACHILLES / J.Smith). Tapping a Submitted/Amended/Late row remains inert
(`CatchRecordRouting.entryRoute(for:)` only resolves an entry route for `.unsent`) — the future
journey for reviewing/amending an already-submitted record is explicitly deferred to a later ADR,
as agreed.

## Consequences

- Home's list is now genuinely data-driven and offline-first: local drafts are always shown even
  with no connectivity or if the (stubbed) server call fails, and a draft persists and reappears
  across app restarts (ADR-0014).
- `DraftActionViewModel.resumeDraft()` looks up the persisted payload by `row.localID` (when
  present) before restarting the journey at `.selectVessel`, so "Complete" on a real Unsent row
  actually loads what was previously captured; a row with no `localID` (e.g. a hand-built
  preview/test row) still routes forward, just with a blank draft.
- Coverage: `RecordsRepositoryTests` (pure `RecordsMerging` functions + end-to-end
  `MergingRecordsRepository`) and `HomeViewModelTests` (all four load states, recovery after
  failure) meet the ≥95% core-logic coverage target.

## References

- ADR-0004 (API-shaped stub seam pattern, reused for `ServerRecordsProviding`/`RecordsProviding`).
- ADR-0014 (on-device draft persistence — the local half of this merge).
- `docs/design-specs/home.md` (visual states, accessibility annotations, copy table).
- GOV.UK Design System, *Notification banner* (error/status presentation pattern) —
  https://design-system.service.gov.uk/components/notification-banner/
