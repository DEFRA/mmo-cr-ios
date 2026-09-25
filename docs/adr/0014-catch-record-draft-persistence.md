# ADR 0014 — On-device persistence of the in-progress catch record (SwiftData)

- Status: Accepted
- Date: 2026-09
- Deciders: iOS engineering
- Context tags: persistence, offline-first, data-at-rest, native-iOS

## Context

`CatchRecordDraft` (ADR-0005) is the single, `@Observable`, `@MainActor`, journey-scoped
accumulator of every value captured while creating a catch record. Until now it lived **only in
memory**: quitting the app, or the app being terminated by the system, silently discarded any
in-progress record. This does not meet the DEFRA mobile requirement that the app "assumes no
connectivity by default" and remains useful across interruptions — a fisher recording a catch at
sea is exactly the situation where the app may be backgrounded, killed for memory, or the device
restarted before a record is finished.

The Home screen's requirement (ADR-0015) is that an **Unsent** record — including one that is only
partially complete — must reappear after the app is relaunched and be resumable. That requires the
draft to survive process termination, i.e. genuine on-device persistence, not just an in-memory
reference type shared for the lifetime of one `CatchRecordHostView`.

## Decision

### 1. SwiftData as the persistence engine

We use **SwiftData** (already wired into the app via `record_catchApp`'s `ModelContainer`,
previously only holding the project template's placeholder `Item` model). SwiftData is Apple's
first-party, `Codable`-friendly persistence framework, requires no new dependency (SPM-only
constraint), and integrates with `@Environment(\.modelContext)` the same way the rest of the app
already consumes environment-scoped dependencies.

### 2. One denormalised `@Model` entity, one JSON payload column

`Core/Persistence/CatchRecordEntity.swift`:

```swift
@Model final class CatchRecordEntity {
    @Attribute(.unique) var localID: UUID
    var lastEditedAt: Date
    var isSubmitted: Bool
    var vessel: String?
    var tripEndDate: Date?
    var payload: Data // JSON-encoded CatchRecordDraftPayload
}
```

- `vessel` / `tripEndDate` are **denormalised** onto the entity so Home's row can be rendered
  cheaply (`UnsentDraftSummary`) without decoding the full payload for every row.
- The full, resumable state is a single JSON-encoded `payload: Data` blob
  (`CatchRecordDraftPayload`, a `Codable`, `Sendable` value-type snapshot of every field
  `CatchRecordDraft` accumulates: vessel, dates, ports, gear catches, species not landed). Modelling
  every nested value (`GearCatch`, `PortOption`, `SpeciesOption`, …) as its own SwiftData
  relationship graph was rejected: these are already plain, `Sendable`, `Codable`-able value types
  used throughout the journey, and a relationship graph would add SwiftData migration surface for
  no behavioural benefit at this phase. `PortOption`, `GearOption`/`GearMeasurement`,
  `SpeciesOption` and `GearCatch` all gained `Codable` conformance to support this.
- `CatchRecordDraft` gained a stable `localID: UUID` (generated once per draft, `nonisolated(unsafe)`
  since it must be settable from a `nonisolated` convenience initializer — mirroring the class's
  existing default-parameter-friendly `nonisolated init()` pattern), a computed `payload` property,
  and `apply(_ payload:)` to mutate the shared draft in place when resuming.

### 3. `CatchRecordDraftStoring` — an API-shaped protocol seam, mirroring ADR-0004

```swift
@MainActor
protocol CatchRecordDraftStoring {
    func save(_ draft: CatchRecordDraft) async throws
    func loadDraft(localID: UUID) async throws -> CatchRecordDraftPayload?
    func deleteDraft(localID: UUID) async throws
    func allUnsentDrafts() async throws -> [UnsentDraftSummary]
}
```

`SwiftDataCatchRecordDraftStore` is the production implementation (`ModelContext`/
`FetchDescriptor`/`#Predicate`); `InMemoryCatchRecordDraftStore` is a reference-typed test/preview
fake with no `ModelContainer` dependency, keeping view-model tests fast and hermetic — the same
stub-seam pattern used for every other provider in this app. `@MainActor` because every call site
already holds `CatchRecordDraft`/`CatchRecordRouter` on the main actor; this avoids introducing a
second, cross-actor isolation domain purely for persistence.

### 4. When the draft is saved: after every "Save and continue"

Per the agreed decision, the draft is persisted on **every** successful screen submission, not just
at defined checkpoints. `CatchRecordHostView` observes `router.path` and saves whenever the path
changes and `draft.vessel != nil` (i.e. at least the first screen has been answered) — a single,
DRY call site rather than threading a save call through every screen's `submit()`. A journey
abandoned before the very first screen is answered never creates a persisted row.

### 5. Resuming: jump to the last completed section, pre-filled

> **Amended 2026-09.** The original decision below ("restart from the first screen") is
> superseded by this one; the original text is kept struck through for history.
>
> ~~Per the agreed decision, tapping "Complete" on an Unsent record's Draft-action screen does not
> jump to wherever the user left off. It restarts the journey from `.selectVessel`, having first
> loaded the persisted payload and called `draft.apply(payload)` so every already-answered field is
> pre-filled as the user walks forward again.~~
>
> In practice, always restarting at `.selectVessel` meant a user who had reached, say, "Record
> species weights" had to click "Save and continue" through every already-answered screen before
> reaching new ground — reported as a bug (resuming a draft should continue from where the user left
> off). `DraftActionViewModel.resumeDraft()` now resumes at the furthest section the draft had
> reached, via a new, deliberately coarse `CatchRecordCheckpoint` on `CatchRecordDraft`/
> `CatchRecordDraftPayload`:
>
> ```swift
> enum CatchRecordCheckpoint: Int, Codable, Comparable, Sendable {
>     case vessel, tripDates, ports, gear, landingStorage, checkYourAnswers
> }
> ```
>
> - **One case per major section**, not one per `CatchRecordRoute` case. Reconstructing the exact
>   `CatchRecordRoute` the user was on would require persisting extra transient state that isn't
>   otherwise part of the draft (e.g. which gear is mid-catch-capture before it has any recorded
>   species, or the one-off `PortOption`/`GearOption` a "Change" mini-journey was showing) — a much
>   larger persistence surface for a purely navigational concern. A coarse checkpoint keeps the
>   change additive: only the existing "section boundary" view models
>   (`TripStartedTodayViewModel`, `TripDateViewModel`, `ConfirmSamePortViewModel`,
>   `SelectPortViewModel`, `RecordSpeciesWeightsViewModel`) gained a single `draft.advance(to:)`
>   call, plus one central hook in `CatchRecordHostView`'s existing `onChange(of: router.path)` for
>   reaching Check your answers (reachable from several places — a single DRY hook covers them all).
> - **Monotonic — `advance(to:)` only ever moves forward.** A "Change" link revisiting an earlier
>   screen (ADR-0013) must not regress how far a resumed draft jumps to.
> - **Resuming reuses the existing forward-journey entry-point helpers** (`CatchRecordRouting.
>   portEntryRoute`/`gearEntryRoute`), re-checking favourites at resume time, so the has-favourites
>   branching is identical whether reached going forward or resuming.
> - **Known simplification:** if a draft is killed exactly between answering "any catch not landed
>   straight away?" and finishing the not-landed-species screen, resuming lands on Check your
>   answers rather than re-opening that one sub-screen; the user can use "Change" there. This was
>   judged an acceptable trade-off against a materially larger persisted-state change for a narrow
>   interruption window.
> - **Backward-compatible decoding:** `checkpoint` decodes via a custom `init(from:)` that falls back
>   to `.vessel` for any draft already persisted before this field existed, so no migration step is
>   needed and no existing on-disk draft fails to decode.

Each screen's own `init` still reads straight from the shared `CatchRecordDraft` to seed its local
selection/value state (matching the existing per-screen pre-fill pattern already used for
ADR-0013's "return to Check your answers" resume flow) — there is no separate "resume coordinator".
Fields not yet captured render as a placeholder ("—") on Home, per decision #6.

### 6. Deletion

Deleting a draft (`DraftAction`'s Delete option, after its destructive confirmation) removes the
persisted row via `draftStore.deleteDraft(localID:)`. A draft is also deleted once it is
successfully submitted (`SubmissionConfirmationViewModel.submit()`), since a submitted record is no
longer "Unsent" — it becomes a server-sourced row instead (ADR-0015). Both are fire-and-forget
`Task { try? await ... }` calls, consistent with the existing "never block navigation on IO"
pattern elsewhere in this module (e.g. `DraftActionViewModel.confirmDelete()`).

### 7. Data-at-rest posture

The shared `ModelContainer` is configured `cloudKitDatabase: .none` — device-local only, never
synced to iCloud — since catch-record data has not been through any data-sharing/consent review.
SwiftData's default on-disk store inherits the app's standard file-protection class
(`NSFileProtectionCompleteUntilFirstUserAuthentication` equivalent), meaning the store is
inaccessible before the device's first unlock since boot and is excluded from an unencrypted
device backup while locked — satisfying the DEFRA "protect data at rest" mandatory constraint for
the data currently held (vessel, dates, ports, gear, species; no credentials or tokens). No
additional file-protection entitlement change was required for this phase; if catch-record data
later gains a stricter classification, revisit with `NSFileProtectionComplete`.

## Consequences

- A journey now survives app termination end-to-end: Home always reflects on-device reality,
  including a mid-journey draft that was never explicitly "saved" as a concept the user thinks
  about — every "Save and continue" already persists it.
- Every view model that seeds from `CatchRecordDraft` gained a small, unit-tested pre-fill branch
  in its `init`; this is a narrow, per-screen change, not a new abstraction layer.
- `SubmissionRow` (the Home table's row type) gained an optional `localID: UUID?` and a `sortDate:
  Date` used only for ordering (ADR-0015) — deliberately excluded from its existing content-based
  `Equatable`/`Hashable` conformance so no existing call site/test needed to change its expectations
  of row equality.
- Resuming a draft (decision #5, amended) now depends on `favouritePorts`/`favouriteGears` being
  threaded into `DraftActionViewModel`/`DraftActionView` (previously unused there), so the
  has-favourites branching at resume time matches the forward journey.
- Coverage: `CatchRecordDraftStoreTests` (both store implementations), `CatchRecordDraftTests`
  (`localID`/`payload`/`apply`/`checkpoint`/JSON round-trip, including backward-compatible
  decoding of pre-checkpoint drafts), `DraftActionViewModelTests` (resume routes to every
  checkpoint), and each affected view model's pre-fill/checkpoint tests meet the project's ≥95%
  core-logic coverage target.

## References

- ADR-0004 (API-shaped stub seam pattern, reused here for `CatchRecordDraftStoring`).
- ADR-0005 (`CatchRecordDraft` model).
- ADR-0013 (per-screen resume-from-draft pattern, generalised here to a full-journey restart).
- ADR-0015 (merged Home list — the consumer of this persistence layer).
- Apple, *SwiftData* — https://developer.apple.com/documentation/swiftdata
- DEFRA, *Mobile application standards* (offline-first, protect data at rest) —
  https://defra.github.io/software-development-standards/standards/mobile_app_standards/
