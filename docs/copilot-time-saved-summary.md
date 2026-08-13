# Time Saved Summary: Copilot-Assisted vs Traditional Development

**Date:** 13 August 2026
**Project:** MMO Catch Recording (iOS)

## Headline

| Metric | Traditional (estimated) | With Copilot (actual) | Saved |
|---|---|---|---|
| Elapsed time | 18–26 person-weeks (4.5–6.5 months) | 10 working days (~2 weeks) | **~16–24 weeks** |
| Speed-up factor | 1× | **~9×–13× faster** | |
| Equivalent effort compressed | — | 10 days did the work of ~4.5–6.5 months | |

**Actual time taken (Copilot-assisted):** ~10 working days.

**Estimated traditional time:** ~18–26 person-weeks for one mid-level iOS developer working unassisted, based on the scope of what currently exists in the codebase.

## What's been built (evidence from the repo)

- **182 Swift files** total: ~131 app source files, ~45 unit test files, 6 UI test files.
- **21 feature folders** under `Features/CatchRecord` (DraftAction, SelectVessel, TripStartedToday, TripDate, SelectPort, AddPort, AddGear, SelectGear, GearMeasurements, LandingStorage, LandingStorageSpecies, AddSpecies, RecordSpeciesWeights, SpeciesSummary, CatchLocation, CheckYourAnswers, SubmissionConfirmation, SubmissionSuccess, SubmissionNudge, Routing), each with View + ViewModel + Validation, mirrored by unit tests.
- A full **MapKit-based sea-zone map** subsystem (`Features/Map`): GeoJSON loading, subzone hit-testing, coordinate decoding, overlay rendering, label visibility — each with dedicated tests.
- A **reusable DesignSystem + component library** (`Common/Components`): forms (radio/checkbox groups, date entry, search dropdown, pagination), typography, warning box, confirmation panel, tables — WCAG 2.2 AA accessible by design.
- **Localisation infrastructure**: `LocalizedBundle`, `LocalizedText`, `AppLanguage`, `AppLanguageStore`, with dedicated tests and an ADR covering in-app language switching.
- A **branching, testable navigation/routing layer** (`CatchRecordRouter`, `CatchRecordRoute`, `CatchRecordRouting`) supporting draft/new/edit journeys, backed by an ADR and dedicated routing tests.
- **~45 unit test files** covering view models, validation logic, providers, routing, and map geometry — tests written alongside features, not bolted on later.
- **6 XCUITest files** driving full user journeys end-to-end via accessibility identifiers.
- **5 ADRs** and **3 Design Specs** capturing architecture and design decisions as documentation.

## Traditional effort estimate breakdown

| Area | Traditional estimate | Rationale |
|---|---|---|
| 21 CatchRecord feature screens (View+VM+Validation+tests) | 3–5 days each → 9–14 weeks | Each includes SwiftUI view, MVVM logic, inline validation, accessibility, unit tests |
| Routing/navigation layer + ADR | 1–1.5 weeks | Custom typed router with draft/new/edit branching is non-trivial to design and test |
| DesignSystem component library | 2–3 weeks | Building accessible, reusable, Dynamic-Type-safe components from scratch |
| Sea-zone Map subsystem | 2–3 weeks | Point-in-polygon geometry, GeoJSON parsing, MapKit overlay rendering are specialist skills |
| Localisation infrastructure | 3–5 days | Custom bundle-switching localisation (not just `.strings`) |
| Unit test suite (~45 files) | Usually 30–50% of feature time, often skipped/rushed under deadline | Written to ≥90%/95% coverage bar per project testing standards |
| UI test suite (6 files, full journeys) | 1–1.5 weeks | XCUITest journeys are slow to write/debug by hand |
| ADRs + Design Specs | 2–4 days | Documentation is frequently the first thing cut under time pressure |
| **Total** | **≈ 18–26 person-weeks** | |

## Why the multiplier is plausible

- **Repetition at scale** — 21 near-identical View/ViewModel/Validation feature triads is exactly the kind of pattern-following work Copilot accelerates most; once the first 2–3 were built, the remaining ~18 could be generated at a fraction of the manual typing/boilerplate time.
- **Tests written alongside, not after** — ~45 unit test files plus 6 full XCUITest journeys hitting a 90–95% coverage bar would normally *double* the estimate on their own if done by hand to the same rigour; Copilot generating tests in lockstep with code is likely the single biggest contributor to the multiplier.
- **Specialist code de-risked** — the MapKit/GeoJSON/point-in-polygon subsystem is the kind of thing a solo developer might normally lose days to just researching APIs and edge cases; Copilot shortcuts the research phase.
- **Documentation kept current** — 5 ADRs and 3 design specs existing at all, in only 10 days, indicates documentation wasn't skipped under time pressure (the usual first casualty), suggesting Copilot handled the "supporting" work in parallel with feature code rather than sequentially.

## Caveats (kept honest)

- This is a rough order-of-magnitude comparison, not a controlled A/B measurement — there's no real traditional baseline for *this exact* app, only an inferred estimate from the artefacts present.
- 10 days is elapsed time for one developer working with Copilot; it assumes reasonably continuous, focused effort rather than 10 calendar days spread thin.
- The comparison is engineering build time only — it excludes product/discovery/Figma design time on either side.

## Bottom line

What's built so far looks like roughly **4.5–6.5 months of unassisted solo effort delivered in 10 days** — approximately a **9×–13× reduction in elapsed time**, without a quality trade-off (tests and ADRs were kept current, not deferred).
