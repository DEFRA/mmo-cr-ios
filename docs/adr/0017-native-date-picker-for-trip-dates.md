# ADR-0017: Native `DatePicker` for trip dates (deviation from the GOV.UK date-input pattern)

## Status

Accepted

## Context

The "Create a catch record" journey asks for two dates — trip departure and trip return — on the
reusable `TripDateView`/`TripDateViewModel` screen (`TripDatePhase.departure` / `.return`). This was
originally built as `DateEntryField`: a bespoke day/month/year text-entry component implementing
the [GOV.UK Design System *Date input*](https://design-system.service.gov.uk/components/date-input/)
component, with a companion `TripDateValidation` rule ("is this a real calendar date?").

Per this repo's standards precedence (**DEFRA > GDS > Apple > community** —
[copilot-instructions.md](../../.github/copilot-instructions.md) §1), the GOV.UK pattern is the
default choice for a date a user already knows. The GOV.UK
[*Ask users for dates*](https://design-system.service.gov.uk/patterns/dates/) pattern reserves a
calendar-style control for when users need to "pick a date in the near future or recent past",
"know the day of the week... as well as the date", or "see dates in relation to other dates" — and
explicitly requires that such a control still "allow users to enter the date into a text input as
well as use the control."

The product decision (this ADR) is to replace `DateEntryField` with SwiftUI's native `DatePicker`
for both trip-date screens. **This is a deliberate deviation from the GOV.UK *Date input*
component**, made because:

- A trip departure/return date is *always* a recent-past date (within the app's supported
  reporting window) — squarely the case the GDS *dates* pattern carves out for a calendar control.
- The compact `DatePicker` style's modal editor still accepts numeric keyboard entry as well as the
  calendar grid, satisfying the GDS pattern's "allow text entry as well as the control" requirement.
- A native control is the idiomatic, well-tested Apple HIG affordance
  ([Pickers](https://developer.apple.com/design/human-interface-guidelines/pickers)) for a native
  iOS app, reducing bespoke validation code and its own accessibility surface to maintain.

This deviation should be logged with Delivery Architecture
(`delivery.architecture@defra.gov.uk`) per the working framework's deviation-recording rule.

## Decision

1. **Component:** Replace `DateEntryField`/`DateEntryValue` with a new `TripDatePicker` component
   wrapping SwiftUI's `DatePicker(selection:in:displayedComponents: .date)`.
2. **Style:** Use `.datePickerStyle(.compact)`. The always-visible `.graphical` calendar was
   rejected — its day cells are frequently smaller than the WCAG 2.2 (2.5.8) / Apple HIG 44×44pt
   minimum target size and it reflows poorly at large Dynamic Type sizes. `.wheels` was rejected for
   the same Dynamic Type/VoiceOver concerns.
3. **Default value:** `TripDateViewModel.selectedDate` is a **non-optional `Date`**, defaulted to
   today (or the resumed draft's already-captured date — see ADR-0015 decision #1). `DatePicker`
   cannot bind to an optional `Date`, so unlike the old three blank text fields, the screen always
   shows a concrete date pre-selected. This is an accepted trade-off (see Consequences).
4. **Validation → range constraint:** `TripDateValidation` and its "missing field"/"not a real
   date" error states are removed entirely. Instead, `TripDateViewModel.selectableRange` clamps the
   picker so an invalid value can never be selected:
   - **Departure:** any day up to and including today.
   - **Return:** on or after the recorded departure date, and no later than today.

   `DateEntryField.parsedDate(from:)`'s bespoke calendar-arithmetic validation, the
   `catchRecord.tripDate.*.validation.*` error copy, and the screen's inline error UI are all
   deleted as a consequence — there is nothing left for them to validate.
5. **Persisted value is normalised to `startOfDay`.** `DatePicker` returns a `Date` carrying the
   current time of day; `submit()` writes `calendar.startOfDay(for: selectedDate)` into the draft.
   This preserves `SubmissionNudge.isNeeded`'s existing raw 24-hour `timeIntervalSince` comparison,
   which assumed a midnight-normalised date under the old component.

## Consequences

- **Data-quality trade-off (accepted).** Because the picker always shows a concrete, valid date, a
  user can tap "Save and continue" through both date screens without ever making a deliberate
  choice, silently recording today's date for both departure and return. The old component forced
  an explicit entry (or an inline error). This trade-off was discussed and accepted for this
  iteration; if field data suggests this happens often, revisit with a "confirm the date" step or
  a non-today default.
- **Loss of explicit GOV.UK-worded errors.** "Enter the day you left for your trip" /
  "Date of birth must be a real date"-style copy no longer exists for this screen; SwiftUI/Apple's
  built-in constraint (greyed-out, untappable dates outside `range`) communicates the limit
  instead. This is a lower level of explicit written guidance than the GDS pattern recommends,
  accepted as part of the same trade-off.
- **Test surface reduced.** `DateEntryFieldTests` and `TripDateValidationTests` are deleted;
  `TripDateViewModelTests` is rewritten around `selectedDate`/`selectableRange` instead of
  `DateEntryValue`/`errorKey`. The corresponding UI tests
  (`record-catchUITests/CatchRecordUITests.swift`) no longer exercise an inline-error path for
  trip dates, since none exists.
- **Localisation:** `component.dateEntry.day/.month/.year` and
  `catchRecord.tripDate.validation.none` string-catalog keys are removed. The hint copy for both
  screens changes from "Enter the date you departed/returned. For example, 31/03/2020" to "Select
  the date you left for/returned from your trip." The Welsh (`cy`) translations for the new hint
  copy are a same-session draft translation marked `needs_review` in the string catalog and
  **require sign-off from a Welsh linguist** before this ships to production, per the DEFRA
  bilingual content obligation.
- **Accessibility.** `TripDatePicker` exposes an `accessibilityLabel` equal to the screen's
  question and a stable `<prefix>.picker` accessibility identifier. Dynamic Type, VoiceOver value
  announcement, and 44×44pt tap-target conformance for the compact picker's own control were
  verified manually (see the change's validation notes); the `.compact` style's popover calendar
  itself is Apple-maintained UI, not custom-built, so its internal target sizes are Apple's
  responsibility to keep AA-conformant.
- **`AppControlSize.dateFieldShortWidth`/`dateFieldYearWidth`** (the old three-field component's
  fixed widths) are removed as dead code; `dateFieldHeight` is retained and reused as the picker's
  minimum height.

## References

- [GOV.UK Design System — Date input](https://design-system.service.gov.uk/components/date-input/)
- [GOV.UK Design System — Ask users for dates](https://design-system.service.gov.uk/patterns/dates/)
- [Apple HIG — Pickers](https://developer.apple.com/design/human-interface-guidelines/pickers)
- ADR-0003 (create-catch-record navigation), ADR-0013 (Check your answers "Change" routing),
  ADR-0015 (resumed-draft pre-fill)
