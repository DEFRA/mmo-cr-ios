# ADR-0028: Catch-record submission queue

## Status

Accepted

## Context

ADR-0025 built the Catch Recording Service connector (`CatchRecordServicing`/`CatchRecordService`) and
ADR-0026 gave every draft a client-generated reference the moment a vessel is confirmed — but neither
wired "Accept and submit trip details" on Check your answers to a real network call. DEFRA's
offline-first mandate (copilot-instructions.md §3) means a fisher mid-voyage with no signal must still
be able to complete and "submit" a catch record: the action must always succeed locally and
immediately, with the actual backend submission happening transparently, in the background, whenever
connectivity allows.

This ADR records the on-device submission queue that closes that gap: how a record moves from
"completed by the user" to "confirmed submitted by the backend", what triggers a send attempt, and how
version/idempotency/conflict handling keeps repeated attempts safe.

## Decision

### 1. Always succeeds locally, first

`CheckYourAnswersViewModel`'s "Accept and submit trip details" action always calls
`CatchRecordSubmissionQueuing.enqueue(_:)` first, which persists the draft and marks it queued
(`CatchRecordDraftStoring.enqueueForSubmission(_:)`) **before** any network attempt — a record is never
lost even if the app is killed immediately afterwards. The screen then calls `submitNow(localID:
timeout:)`, which tries to send immediately (bounded by a timeout) but — whatever the outcome — the
user is only ever shown a screen consistent with reality: the real "submitted" confirmation only for
`.submitted`, and the truthful "saved on this device" screen for `.queued`/`.failedPermanently`
(BR-SUB-008/AC10/AC11). The action is never blocked on connectivity.

### 2. `CatchRecordQueueState`: three states, UI-derived status

`CatchRecordEntity.queueStateRaw` (`CatchRecordQueueState`: `.none` / `.pending` / `.sending`) is the
only new backend-agnostic state this ADR introduces. `CatchRecordStatusResolver.status(queueState:
backendStatus:submissionCount:)` derives the **UI-managed** `SubmissionStatus` purely from this local
state plus the last-known backend status:

| Status            | Backend persisted? | Rule |
|--------------------|---------------------|------|
| Draft              | ✅ (`DRAFT`)        | Started but not yet successfully submitted. |
| Submitted          | ✅ (`SUBMITTED`)    | Successfully submitted and received. |
| Complete/Pending   | ❌ (UI only)        | Completed on-device, queued or sending — mobile only; always wins over a stale backend status (AC3/AC4). |
| Amended            | ❌ (UI only)        | Previously submitted (`submissionCount > 1`), since re-submitted (AC5). |

**Known backend status gap:** the Catch Recording Service's schema also allows a `COMPLETE` status
outside the two values AC7 permits (`DRAFT`/`SUBMITTED`); this resolver treats it identically to
`SUBMITTED` rather than failing to resolve a status at all.

### 3. `CatchRecordSubmissionCoordinator`: single in-flight run, never piles up

`CatchRecordSubmissionCoordinator` (`@MainActor @Observable`, conforming to the narrow
`CatchRecordSubmissionQueuing` seam so view models never talk to `CatchRecordServicing` directly)
deliberately mirrors `ReferenceDataSyncCoordinator`'s shape: a single in-flight `flushPending()` run plus
a trailing "run again" flag, rather than a queue of overlapping attempts — both solve the same "attempt
best-effort background work, never pile up concurrent attempts" problem. `lastFlushCompletedAt` is
observed by `HomeView` to reload its list once a Complete/Pending record resolves to Submitted (AC4).

Two deterministic test doubles exist alongside the real coordinator: `StubCatchRecordSubmissionQueue`
(always queues, never sends — the safe default for an unconfigured preview, mirroring
`StubConnectivityMonitor`) and `AlwaysSucceedingCatchRecordSubmissionQueue` (used only by UI tests that
need to reach the real `submissionSuccess` screen without a reachable backend).

### 4. Triggers

`flushPending()` is attempted, from `RecordCatchApp`, on:

- **App foreground.**
- **Connectivity restored** (`ConnectivityMonitoring.isOnline` transitioning `false` → `true`).
- **`submitNow(localID:timeout:)`'s own best-effort immediate attempt**, racing a timeout so the caller
  never blocks indefinitely — if the timeout wins, the attempt is left running in the background and
  completes via the normal queue/flush path (never silently abandoned, never double-counted).

`flushPending()` is a no-op while offline or while already flushing (the trailing-flag re-run covers
anything enqueued mid-flush).

### 5. Create → replace → submit, reusing one idempotency key per cycle

Each attempt (`attemptSubmission(localID:)`) follows the Catch Recording Service's documented lifecycle
(ADR-0025):

1. **Create** the server-side draft record (`createDraft`) if no server id is yet known for this
   `localID` — carrying the client-generated `catchRecordReference` (ADR-0026) and `vesselId`.
2. **Replace** its full content (`replaceCatchRecord`, `If-Match` against the last known version).
3. **Submit** (`submit`), reusing the version `replaceCatchRecord` itself just returned — never the
   stale version `createDraft`/a previous attempt returned, since the service bumps the version on
   every successful write and submitting against a pre-replace version would always conflict.

A single `idempotencyKey` (`CatchRecordEntity.idempotencyKey`, generated once in
`enqueueForSubmission(_:)`) is reused across every retry of one submission cycle, so a retried request
is provably the same logical submission if the backend already applied a response that was lost in
transit — cleared only once the backend confirms success (`markSubmissionSucceeded`) or the attempt is
abandoned as a permanent failure.

### 6. Conflict handling (`409`)

`submitWithConflictRetry` retries **once**, against a freshly retrieved version, if `submit` reports a
`409` conflict (another session/device moved the record's version between this attempt's replace and
submit) — bounded so a persistent conflict still resolves definitively rather than looping forever. If
the backend's current state already shows the record as `submitted` (`resolveConflict`), that means a
previous attempt's response was simply lost in transit, not a genuine conflict: the record is marked
submitted locally to match and nothing further is sent. A replace-side conflict is not separately
retried — `replace` already received the latest version this attempt knew about, so a conflict there
reflects a genuinely concurrent edit and is left to the outer `APIError` handling (queued/failed like
any other error).

### 7. Error handling: retryable vs permanent

- **Retryable** (left `.pending`, retried automatically by the next trigger): `APIError.isRetryable`
  (network/offline/5xx), `APIError.invalidConfiguration` (the Catch Recording Service not yet
  configured for this stage/build — an environment/deployment problem, never something the user caused
  or can fix on this screen), and **`401 Unauthorized`** (an expired/not-yet-ready sign-in session —
  nothing the user can fix from this screen either; the queue retries once the app's normal silent
  session-refresh/re-sign-in flow restores a valid token). None of these ever revert the record to
  Draft.
- **Permanent** (reverted to **Draft**, `markSubmissionFailed(permanent: true)`): a mapping/validation
  failure (`CatchRecordMappingError`, missing local draft/queue progress) — bad or incomplete local
  data the user can act on by resuming and fixing the draft. The user sees a recoverable inline error,
  never a silent dead end.
- A non-sensitive, machine-readable `errorCode` (from the decoded API error envelope, or a fallback
  constant otherwise) is recorded for diagnostics — never the raw response body, which could carry
  sensitive detail.

### 8. Vessel snapshot (backward-compatible)

`CatchRecordDraft.vesselSnapshot: VesselOption?` captures the full, API-sourced vessel record at
selection time (`SelectVesselViewModel.submit()`), alongside the pre-existing `vessel: String?`
display-name field. `CatchRecordSubmissionCoordinator.resolveVessel(for:)` and
`CatchRecordReferenceGeneration` prefer the snapshot when present, falling back to a `vesselProvider`
name lookup only for a draft persisted before this field existed (`vesselSnapshot == nil`) — so a
record submitted long after being drafted does not depend on the vessel still being resolvable by name
from whatever reference-data snapshot happens to be on-device at submission time. Both
`CatchRecordDraft`/`CatchRecordDraftPayload` decode `vesselSnapshot` as `nil` by default (mirrors the
existing `catchRecordReference`/`checkpoint` precedent), so every already-persisted draft continues to
decode and resume unchanged.

## Known simplifications (flagged, not hidden)

- **Statistical-area id/name synthesis.** `CatchRecordPayloadMapper` does not yet have a real
  statistical-area reference dataset to map a trip's fishing location against; it currently
  synthesises a plausible id/name pair from the location data already captured in the draft. This is a
  known, deliberate simplification pending a real statistical-areas reference dataset — track as a
  follow-up.
- **No separate replace-side conflict retry.** As above, a `409` from `replaceCatchRecord` itself is
  not retried inline — it is treated like any other `APIError` (queued/failed), on the basis that the
  replace attempt already used the most recent version this cycle knew about.
- **Native-app exception.** As with every feature in this app, built against the already-recorded
  native-iOS exception to DEFRA's mobile app standards (see copilot-instructions.md §2).

## Consequences

- A catch record is **never lost**: "Accept and submit trip details" always persists and queues the
  record locally first, and the user is only ever shown a status consistent with what has actually
  happened (submitted vs saved-on-device-and-queued).
- Home's record list gains a **Complete/Pending** and **Amended** status, both UI-derived and never
  persisted to the backend, alongside the backend's own `Draft`/`Submitted`.
- Every submission attempt is **idempotent and resumable**: killing the app, losing connectivity
  mid-attempt, or a backend that bumps the version from another client are all handled without
  duplicating or corrupting the server-side record.
- `VesselOption` snapshots now travel with the draft, so submission/reference generation for a record
  drafted long ago no longer depends on that vessel still being resolvable from the current
  reference-data snapshot (see ADR-0024's vessel consumer note).
