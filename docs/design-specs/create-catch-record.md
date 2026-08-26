# Design Spec — Create a catch record, Part 1 (UI only)

Feature: bilingual "Create a catch record" journey, Part 1 — three screens: Draft action,
Select vessel, Did your trip start and finish today?
Scope: **UI only**. No persistence, networking, or offline sync. Vessels are a static list behind
a swappable provider; the reference number is a display-only placeholder. See
[ADR-0003](../adr/0003-create-catch-record-navigation.md) for the navigation architecture.

## Entry points

- **Home → "Create a new catch record"** (`Home.createRecordButton`) calls
  `router.startNew()` → pushes straight to **Select vessel** (no existing draft).
- **Home → submissions table date link** for an **Unsent** row calls
  `CatchRecordRouting.entryRoute(for:)`, which resolves to `.draftAction(row)` and pushes
  **Draft action**. Any other status resolves to `nil` and stays inert (unchanged from today).

## Screen 1 — Draft action (`CatchRecord.draftAction.*`)

Rendered via `ViewTemplate(title: "")` (empty title — the screen renders its own caption + H1).

1. Caption "New catch record" (`AppTypography.pageCaption`, `govBlue`).
2. H1 — "What do you want to do with your draft record?" (`TitleText`).
3. `RadioGroup` — Complete (`.option.complete`) / Delete (`.option.delete`).
4. `PrimaryButton` "Save and continue" (`.saveContinue`).
5. **Delete** + continue → destructive `confirmationDialog` ("Delete this draft record?" /
   confirm `.deleteConfirm` / cancel `.deleteCancel`). Confirm → `router.popToRoot()` (back to
   Home). Cancel → dialog dismisses, selection unchanged.
6. **Complete** + continue → `router.push(.selectVessel)`.

## Screen 2 — Select vessel (`CatchRecord.selectVessel.*`)

1. Caption "New catch record", H1 "Select the vessel for this trip".
2. `RadioGroup` sourced from `VesselProviding` (`StaticVesselProvider`: ACHILLES, HERCULES) —
   `.option.achilles` / `.option.hercules`.
3. `PrimaryButton` "Save and continue" (`.saveContinue`).
4. Continue → `router.push(.tripStartedToday(referenceNumber: <placeholder>))`.

## Screen 3 — Did your trip start and finish today? (`CatchRecord.tripToday.*`)

1. Caption "New catch record", display-only reference number header
   (`.referenceNumber`, placeholder e.g. `A1234520260727150815`, `bodySmall`/`textSecondary`).
2. H1 "Did your trip start and finish today?".
3. Two hint paragraphs: "Select yes if you're recording today's trip now." / "Select no if you're
   recording a trip from another day — you'll then enter the dates."
4. `RadioGroup` Yes (`.option.yes`) / No (`.option.no`).
5. `PrimaryButton` "Save and continue" (`.saveContinue`).
6. Continue → `router.push(.placeholderNextStep)` — a minimal placeholder screen ("Next step —
   coming soon") that ends Part 1 of the journey.

## Screen — Late-submission nudge (`CatchRecord.submissionNudge.*`)

Interposed after a valid **trip end (return) date** when the trip ended **more than 24 hours** before
"now" (records must be submitted within 24 hours of a trip ending). The decision is pure
(`SubmissionNudge.isNeeded` / `daysLate`) with an injectable clock, so it is deterministic in tests.

1. Caption "New catch record", display-only reference number header (`.referenceNumber`).
2. H1 "This catch record is being submitted **x days** after the trip end date"
   (`.heading`, `x` = whole calendar days late via `%lld`).
3. Guidance paragraph: "Catch records must be submitted within 24 hours of a trip ending."
   (`.body`).
4. Link "Check the trip end date is correct before you continue" (`.checkDateLink`) — a real
   `Button` (44×44pt target, `.isLink` trait) that pops back to the trip end date screen to correct
   the date.
5. `PrimaryButton` "Save and continue" (`.saveContinue`) → acknowledges and continues into the port
   sub-journey (the same next step the return date screen would have taken).

When the trip ended **within** 24 hours (or the entered date is in the future), the nudge is skipped
and the journey continues straight into the port sub-journey.

## Screen — Check your answers (`CatchRecord.checkYourAnswers.*`)

Ends the journey. Reached from the landing-storage sub-journey; a read-only summary of every value
captured in `CatchRecordDraft`, each row pairing a label with a "Change" control that returns the
user into the journey at the screen where that value was captured.

1. Caption "New catch record", display-only reference number header (`.referenceNumber`).
2. H1 "Check your answers" (`.heading`).
3. Four ordered sections (`.section.<id>`), each an H2-level heading:
   - **Trip** (`.section.trip`) — vessel, departure date, return date, departure port, return
     port, statistical area. Always rendered, even with zero rows if nothing has been captured yet.
   - **Gear used** (`.section.gear`) — gear name plus its captured measurements (e.g. mesh size).
     Always rendered.
   - **Species caught** (`.section.speciesCaught`) — one row set per species landed (name + weight
     above minimum size, plus below-minimum/discarded weights where captured). Omitted entirely
     when no species have been recorded.
   - **Species not landed** (`.section.speciesNotLanded`) — one row set per species kept
     onboard/in keep pots (name + weight). Omitted entirely when empty.
4. Each row (`.change.<rowId>`) shows a label + formatted value and a "Change" link
   (`AppColors.linkText`, underlined) that pushes the route for the screen where that value was
   captured (e.g. dates → trip-date screen, ports → select-port screen, area → catch-location map,
   vessel → select-vessel, gear → gear-measurements, species → the relevant weights screen).
   Tapping Change **pushes forward** into the journey (not a pop) so the existing "Save and
   continue" flow naturally returns here once the user re-confirms the changed value.
5. This is a **UI-only, unsubmitted** summary in this phase — there is no further "Submit" action
   past this screen; see the design spec's placeholder-next-step note for what comes after.

## States (per screen)


| State | Trigger | Presentation |
|---|---|---|
| Default | Initial | No option selected, no error |
| Selected | User taps an option | `RadioOption.isSelected`, VoiceOver `.isSelected` trait |
| Error on submit | "Save and continue" tapped with no selection | Inline red error (icon + text) below the group, red border around the group, VoiceOver "Error:" / "Gwall:" prefix; does **not** navigate |

Load/empty/networking states are **future-API placeholders** — out of scope while vessels and the
reference number are static/stubbed. When Select vessel is backed by a real API, add
loading/empty/error states there without changing this journey's navigation or validation pattern.

## Colours / typography / spacing

Reuses the Sign In / Home tokens unchanged: `govBlue` (caption/header), `govGreen` (primary
button), `errorRed` (validation), `textPrimary`/`textSecondary`, `AppTypography.pageCaption` /
`pageTitle` / `body` / `hint` / `error` / `button`, `AppSpacing.small/medium/large`.

## Copy table (en / cy)

Welsh values below are **placeholders pending translation**; each is marked `needs_review` in the
String Catalog (never a `[CY-TODO]` prefix in rendered copy).

| Key | English | Welsh (placeholder) |
|---|---|---|
| `catchRecord.caption` | New catch record | Cofnod dalfa newydd |
| `catchRecord.draftAction.heading` | What do you want to do with your draft record? | Beth hoffech chi ei wneud gyda'ch cofnod drafft? |
| `catchRecord.draftAction.option.complete` | Complete this record | Cwblhau'r cofnod hwn |
| `catchRecord.draftAction.option.delete` | Delete this record | Dileu'r cofnod hwn |
| `catchRecord.draftAction.validation.none` | Select what you want to do with your draft record | Dewiswch beth hoffech chi ei wneud gyda'ch cofnod drafft |
| `catchRecord.draftAction.delete.title` | Delete this draft record? | Dileu'r cofnod drafft hwn? |
| `catchRecord.draftAction.delete.message` | This cannot be undone. | Ni ellir dadwneud hyn. |
| `catchRecord.draftAction.delete.confirm` | Delete record | Dileu'r cofnod |
| `catchRecord.draftAction.delete.cancel` | Cancel | Canslo |
| `catchRecord.selectVessel.heading` | Select the vessel for this trip | Dewiswch y llong ar gyfer y daith hon |
| `catchRecord.selectVessel.option.achilles` | ACHILLES | ACHILLES |
| `catchRecord.selectVessel.option.hercules` | HERCULES | HERCULES |
| `catchRecord.selectVessel.validation.none` | Select a vessel | Dewiswch long |
| `catchRecord.tripToday.heading` | Did your trip start and finish today? | Wnaeth eich taith ddechrau a gorffen heddiw? |
| `catchRecord.tripToday.hint.yes` | Select yes if you're recording today's trip now. | Dewiswch ie os ydych chi'n cofnodi taith heddiw nawr. |
| `catchRecord.tripToday.hint.no` | Select no if you're recording a trip from another day — you'll then enter the dates. | Dewiswch na os ydych chi'n cofnodi taith o ddiwrnod arall — byddwch wedyn yn nodi'r dyddiadau. |
| `catchRecord.tripToday.option.yes` | Yes | Ie |
| `catchRecord.tripToday.option.no` | No | Na |
| `catchRecord.tripToday.validation.none` | Select whether your trip started and finished today | Dewiswch a wnaeth eich taith ddechrau a gorffen heddiw |
| `catchRecord.saveContinue` | Save and continue | Cadw a pharhau |
| `catchRecord.submissionNudge.heading` | This catch record is being submitted %lld days after the trip end date | Mae'r cofnod dalfa hwn yn cael ei gyflwyno %lld diwrnod ar ôl dyddiad diwedd y daith |
| `catchRecord.submissionNudge.body` | Catch records must be submitted within 24 hours of a trip ending. | Rhaid cyflwyno cofnodion dalfa o fewn 24 awr i daith yn dod i ben. |
| `catchRecord.submissionNudge.checkDateLink` | Check the trip end date is correct before you continue | Gwiriwch fod dyddiad diwedd y daith yn gywir cyn i chi barhau |
| `catchRecord.placeholder.nextStep.heading` | Next step | Cam nesaf |
| `catchRecord.placeholder.nextStep.message` | This part of the journey is coming soon. | Bydd y rhan hon o'r daith ar gael yn fuan. |
| `catchRecord.checkYourAnswers.heading` | Check your answers | Gwiriwch eich atebion |
| `catchRecord.checkYourAnswers.change` | Change | Newid |
| `catchRecord.checkYourAnswers.section.trip` | Trip | Taith |
| `catchRecord.checkYourAnswers.section.gear` | Gear used | Offer a ddefnyddiwyd |
| `catchRecord.checkYourAnswers.section.speciesCaught` | Species caught | Rhywogaethau a ddaliwyd |
| `catchRecord.checkYourAnswers.section.speciesNotLanded` | Species not landed | Rhywogaethau na chafodd eu glanio |
| `catchRecord.checkYourAnswers.label.vessel` | Vessel | Llong |
| `catchRecord.checkYourAnswers.label.departureDate` | Departure date | Dyddiad ymadael |
| `catchRecord.checkYourAnswers.label.returnDate` | Return date | Dyddiad dychwelyd |
| `catchRecord.checkYourAnswers.label.departurePort` | Departure port | Porthladd ymadael |
| `catchRecord.checkYourAnswers.label.returnPort` | Return port | Porthladd dychwelyd |
| `catchRecord.checkYourAnswers.label.statisticalArea` | Statistical area | Ardal ystadegol |
| `catchRecord.checkYourAnswers.label.gear` | Gear | Offer |
| `catchRecord.checkYourAnswers.label.speciesName` | Species | Rhywogaeth |
| `catchRecord.checkYourAnswers.label.weightAbove` | Weight landed | Pwysau a laniwyd |
| `catchRecord.checkYourAnswers.label.weightBelow` | Weight below minimum size | Pwysau o dan y maint lleiaf |
| `catchRecord.checkYourAnswers.label.weightDiscarded` | Weight legally discarded | Pwysau a waredwyd yn gyfreithiol |
| `catchRecord.checkYourAnswers.label.weightNotLanded` | Weight kept onboard | Pwysau a gadwyd ar y llong |
| `a11y.errorPrefix` | (existing) Error: | Gwall: |

## Accessibility annotations

- **Radio groups**: each `RadioGroup` is a single accessibility container labelled by the
  screen's H1; each `RadioOption` carries `.isSelected` when chosen so VoiceOver announces state
  changes (WCAG 4.1.3 Status Messages via the `.isSelected` trait, not colour alone).
- **Errors**: icon + `errorRed` text + red border, combined into one accessibility element with a
  hidden "Error:" / "Gwall:" prefix (WCAG 3.3.1 Error Identification); submitting with no
  selection does not navigate, keeping errors recoverable in place (WCAG 3.3.4).
- **Destructive delete**: uses `confirmationDialog` with a `.destructive` role button, so
  VoiceOver announces it distinctly and it requires an explicit second tap (WCAG 3.3.4 — Error
  Prevention for a data-loss action).
- **Reference number**: presented as a plain static label (`.referenceNumber`), read by VoiceOver
  as ordinary text; not interactive.
- **Dynamic Type**: all copy renders via `TitleText`/`ParagraphText`/`LocalizedText` (no fixed
  frames that would clip at 200%/accessibility sizes).
- **Targets**: `RadioOption` rows and `PrimaryButton` meet the 44×44pt minimum already established
  by those shared components.
- **Reduce Motion**: the push/pop transition honours `UIAccessibility.isReduceMotionEnabled`
  through the standard `NavigationStack` transition (no custom animation added).
- **Language of parts**: all rendered copy goes through `LocalizedText`, carrying the active
  language identifier for correct VoiceOver pronunciation (WCAG 3.1.2).
- **Check your answers**: section headings carry `.isHeader` (H2-level, under the screen's H1) so
  VoiceOver rotor navigation can jump between sections; each row is a single accessibility element
  (`.accessibilityElement(children: .contain)`) so the label and value are announced together, and
  each "Change" control is a real `Button` with the `.isLink` trait, a 44×44pt minimum target
  (`AppControlSize.buttonHeight`), and a composed accessibility label ("Change <field label>", e.g.
  "Change Departure port") rather than a bare "Change" — so VoiceOver users can distinguish the many
  Change links on the screen without extra exploration. Dynamic Type is honoured throughout (no
  fixed frames on label/value text); colour contrast for the link text meets 4.5:1 (WCAG 1.4.3);
  Welsh copy for this screen is `needs_review` pending translation, per the copy table above.

## Reference number placeholder note

The Select vessel → Trip-started-today reference number is a **static placeholder** (matching the
existing internal demo value `A1234520260727150815`) generated client-side with no format
guarantee. It is not derived from any backend and must be replaced once a real submission/reference
API exists — tracked as a future-phase dependency, not part of this UI-only slice.

## Screen — What gear did you use? — variable (per-trip) measurements (`CatchRecord.selectGear.*`)

Reached in the gear sub-journey when the user already has favourite gears. The user ticks each gear
used on the trip (multi-select checkboxes). See ADR-0010 for the required-vs-variable measurement
model.

Gears carry two kinds of measurement, both from gear reference data:

- **Required** (e.g. mesh size) — fixed to the gear, captured once on the gear-measurements screen
  when the gear is added to favourites, and shown here as the checkbox subtitle (e.g. "100mm mesh").
- **Variable** (e.g. number of times shot) — change per trip, captured **here**.

### Conditional reveal

Ticking a gear reveals its variable-measurement field(s) directly beneath the checkbox, indented
with a grey left rule — the GOV.UK "conditionally revealing a related question" pattern. Seine nets
reveals a single whole-number field, "Number of times gear was shot on trip"
(`.variable.<gearId>.timesShot`). Unticking hides the field again.

### Validation

"Save and continue" (`.saveContinue`):

1. At least one gear must be ticked, else the group-level inline error
   `catchRecord.selectGear.validation.none` (`.error`).
2. Every **ticked** gear's variable measurements must be valid whole numbers, else an inline field
   error `catchRecord.gear.measurement.validation.wholeNumber` under the offending field. Unticked
   gears are never validated.

On success the selected gear (with its captured variable values attached) is written to
`CatchRecordDraft.gear` and the journey routes to the catch-location screen. "Add another gear"
(`.addAnother`) opens the Add-gear search screen.

### Check your answers

The gear section shows the gear name, then required-measurement rows (Change → gear-measurements),
then variable-measurement rows with their captured values (Change → this select-gear screen).

### Copy additions (en / cy)

| Key | English | Welsh (placeholder, `needs_review`) |
|---|---|---|
| `catchRecord.gear.variableMeasurement.timesShot` | Number of times gear was shot on trip | Nifer y gweithiau y taflwyd yr offer ar y daith |

### Accessibility annotations

- The revealed field is a **single simple question** placed immediately after its checkbox in the
  accessibility tree, per GOV.UK guidance. GOV.UK documents a known WCAG 2.2 SC 4.1.2 (Name, Role,
  Value) limitation that screen-reader users are not always notified when a reveal appears/hides;
  simple reveals (one field) tested acceptably, so this is followed rather than blocked.
- The field has a visible label (`Number of times gear was shot on trip`), a stable identifier, and a
  number-pad keyboard. Errors are text + icon and announced with the "Error:" / "Gwall:" prefix
  (WCAG 3.3.1); submitting invalid does not navigate (WCAG 3.3.4).
- Checkbox state is conveyed by the tick glyph and `.isSelected` trait, never colour alone. Tap
  targets meet 44×44pt; Dynamic Type is honoured (a "seine nets selected" preview covers the revealed
  field at accessibility sizes).

### Deviation register

- The shared `CheckboxGroup` component was extended with an optional per-option conditional reveal
  (generic + backwards-compatible convenience init) — no existing DesignSystem component rendered a
  conditional reveal. Logged for governance (Delivery Architecture).
