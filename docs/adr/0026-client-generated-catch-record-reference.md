# ADR 0026 — Client-generated catch record reference

- Status: Accepted
- Date: 2026-11
- Deciders: iOS engineering
- Context tags: offline-first, domain-model, native-iOS

## Context

The "Create a catch record" journey has shown a **static, hard-coded placeholder** reference number
(`"A1234520260727150815"`, `SelectVesselViewModel.placeholderReferenceNumber`) on every screen since
the reference number first appeared in the UI, pending a real generation strategy. Offline-first
design (copilot-instructions.md §3, swift-swiftui.instructions.md "Offline-first data") requires the
reference to exist **the moment the user starts a trip**, with no dependency on connectivity or a
server round-trip — a fisher recording a catch mid-voyage, with no signal, must still get a usable
reference immediately.

## Decision

### 1. Format: `{RSS}-{DDMMYYYY}-{HHMMSS}`

`CatchRecordReferenceGenerator` (`Core/Models/CatchRecordReference.swift`) builds
`"{rssNumber}-{ddMMyyyy}-{HHmmss}"`, e.g. `A12345-27072026-150815`, from the vessel's RSS
(Registry of Shipping and Seamen) number and the current UK local time (`Europe/London`, not UTC —
fishers read trip/catch times on local clocks). A fixed `en_US_POSIX`/Gregorian calendar is used for
the date/time components so the result never depends on the user's own calendar/locale preference.

### 2. Generated once, the moment a vessel is confirmed

`SelectVesselViewModel.submit()` generates `draft.catchRecordReference` the instant a vessel is
selected and only if the draft does not already carry one — a resumed draft (`DraftActionViewModel.
resumeDraft()`, loaded from the on-device store, ADR-0014) never regenerates it, keeping the
reference stable for the rest of that catch record's life, including across app restarts and
resuming an in-progress draft from Home.

### 3. RSS number source, and the placeholder fallback

`VesselProviding` gained `rssNumber(forVesselNamed:) -> String?` (defaulted to `nil` via a protocol
extension, so the existing test double `StubVesselProvider` needs no change).
`StaticVesselProvider` — the current stand-in vessel list pending a real vessel API/service — maps
its two demo vessels to fake RSS numbers (`ACHILLES` → `A12345`, `HERCULES` → `H54321`). If a
vessel's RSS number is unknown (`nil`) or generation otherwise fails, the view model falls back to
the existing `placeholderReferenceNumber` constant — a safe, visible degradation that never blocks
the journey — and logs a diagnostic (the vessel name only; never the generated/placeholder value
itself, since neither carries sensitive data, but keeping log content minimal regardless).

### 4. Persistence

`CatchRecordDraft.catchRecordReference: String?` and its `CatchRecordDraftPayload` wire/persisted
counterpart carry the value through save/resume (`CatchRecordDraftStore`,
`SwiftDataCatchRecordDraftStore`'s `CatchRecordEntity.catchRecordReference` denormalised column).
Both are optional with a default of `nil` so every already-persisted draft predating this field
still decodes/loads unchanged (mirrors the existing `checkpointRawValue` precedent) — such a draft
is given a reference the next time it is resumed (`DraftActionViewModel.resumeDraft()` generates one
from the already-captured vessel if `catchRecordReference` is still `nil`).

## Known dependency on the backend team

The Catch Recording Service's `CreateDraftCatchRecordPayload.catchRecordReference` field (see
[ADR-0025](0025-catch-recording-service-connector.md)) is currently documented with validation
pattern `^GBR-[A-Z0-9]+-\d{6}-\d{6}$` — a 2-digit year and a fixed `"GBR"` prefix. This generator's
`{RSS}-{DDMMYYYY}-{HHMMSS}` format (4-digit year, no `"GBR"` prefix) does **not** match that pattern.
Sending this reference to `POST /v1/catch-records` will be rejected by the service until the backend
team updates their validation to accept the app's format. This is flagged, not silently worked
around: the client does not attempt to reshape its reference to fit the documented-but-likely-stale
server pattern, since the server pattern itself looks like it predates this app's agreed format.
Track resolution with the backend team before the Catch Recording Service connector's `createDraft`
is wired to a real screen.

## Consequences

- The placeholder reference number is no longer the *only* reference shown — most journeys (any
  vessel with a known RSS number) now see a real, stable, uniquely-generated reference as soon as
  they pick a vessel.
- The fallback preserves the exact previous behaviour (the static placeholder) for any vessel
  without a known RSS number, so no existing UI test needed to assert against a placeholder had to
  change its *expected value* — only the test's vessel-provider fixture, to keep that path exercised
  deterministically.
- A future real vessel API/service (replacing `StaticVesselProvider`) must populate
  `VesselOption.registrationNumber`/`rssNumber` for `VesselProviding.rssNumber(forVesselNamed:)` to
  keep working end-to-end once the picker is wired to it.
