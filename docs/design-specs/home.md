# Design Spec — Home / "Your trips" (UI only)

Feature: bilingual Home / trips-overview screen for the DEFRA / MMO Catch Recording iOS app.
Scope: **UI only**. No real auth, networking, Keychain, persistence, sync or offline. All data is
**stubbed/static**; pagination is a single stubbed page; the bottom tab bar is out of scope.
`HomeView` is the production screen and **supersedes** `TripsOverviewDemoView` (kept only as a
component showcase).

## Layout (inside `ViewTemplate`)

Rendered via `ViewTemplate(title:warning:) { content }`, inheriting the shared `ViewHeader`
(Back / GOV.UK / language toggle), a scrollable content area and `ViewFooter`. The **warning box and
the page title are rendered by `ViewTemplate` itself** (the warning above the title); `HomeView`
supplies them as parameters. Content, top to bottom:

1. **`WarningBox`** (`Home.warningBox`) — injected via `ViewTemplate(warning:)` so it appears at the
   very top of the content, **above** the title. Blue-bordered box with a solid **gov-blue banner
   containing white "Important" text**, and the message on the white body below.
   `.accessibilityElement(children: .combine)` announces "Important, &lt;message&gt;".
2. **Page title** — "Your trips" rendered by `ViewTemplate` via `TitleText` (`pageTitle`, bold,
   `textPrimary`/black) with the `.isHeader` trait. (Shared change: `ViewTemplate` now renders every
   screen's title as a bold black heading rather than the previous gov-blue caption.)
3. **Three intro paragraphs** — `home.intro.viewSubmitted`, `home.intro.selectDate`
   ("Select an end date…"), `home.intro.webOnly`.
3. **Trips table** — `SubmissionsTable` with a header row (Trip end date | Vessel | Status |
   Created by) and a first-class Created-by column. Column headers carry
   `.accessibilityAddTraits(.isHeader)`. Existing divider / border / status-tag styling and the
   date-cell link button are retained; status tags render on a single line (`.lineLimit(1)` +
   `.fixedSize`). 4 stub rows: 20 Nov 2020 / ACHILLES / {submitted, amended, unsent, late} /
   "J.Smith".
4. **`PaginationControls`** + pure `PaginationState` — renders "← Previous · Showing 1 to 4 of 4 ·
   [1] · Next →". Stubbed single page (so Previous/Next are hidden per the GDS pattern).
5. **`ExpandableHelpSection`** (generic `content:` form) — "How to record a catch"
   (`home.howToRecord.title`, `Home.howToRecord`), collapsed by default. Four sub-sections, each a
   bold sub-heading (`.isHeader` trait) plus paragraph(s), copy routed through `home.howToRecord.*`:
   - *What you need to do* — 2 paragraphs.
   - *When to create your record* — intro paragraph, a 3-item bullet list (quota species /
     non-quota species / crossed an ICES boundary), then a 24-hour deadline paragraph.
   - *Special cases: ICES areas* — 2 paragraphs (ICES 4c/7d/7e boundary-crossing rule; the "use the
     mobile app" offline note — see content flag below).
   - *Get help with your record* — phone number + opening hours, call-cost notice, out-of-hours
     automated-line notice.
6. **`ExpandableHelpSection`** (`items:` form) — "Understanding catch record statuses"
   (`Home.statusHelp`) (Unsent / Submitted / Amended / Late), copy routed through `home.help.*`.
7. **`PrimaryButton`** "Create a new catch record" (`Home.createRecordButton`), inert.

### `ExpandableHelpSection` generalised (direct edit, backward-compatible)

`ExpandableHelpSection` is now generic over its content (`ExpandableHelpSection<Content: View>`),
taking either:
- the original `items: [HelpItem]` heading+paragraph pairs (unchanged behaviour; used by
  `TripFormDemoView`, `TripsOverviewDemoView` and Home's status-help section), or
- an arbitrary `@ViewBuilder content:` closure, used by the new "How to record a catch" section,
  which doesn't fit the flat heading+paragraph shape (it has paragraphs *and* a bullet list under
  some sub-headings).

Both forms share the same disclosure chevron/title button, expand/collapse state, and left-hand
rule styling. An optional `accessibilityIdentifier:` parameter was added so each disclosure's
button carries a stable identifier (`Home.howToRecord` / `Home.statusHelp`) for UI tests, without
changing the existing `#Preview` or other call sites' behaviour.

### Content flag — "use the mobile app" copy

The supplied design mock's *Special cases: ICES areas* block includes: "If you need to record
catches without an internet connection, use the mobile app." Since this screen **is** the mobile
app, that sentence reads oddly in place — it appears to be copy reused verbatim from the
equivalent GOV.UK web-service page. Per the design authority rule, the copy was shipped **as
designed**; this is flagged here (and in the delivery change summary) for content/product review
rather than silently reworded.

### Table is a direct edit (not backward-compatible)

Per the approved decision, `SubmissionsTable` and `SubmissionRow` were edited **directly**:
`SubmissionRow` gains a **required** `createdBy: String`; `SubmissionsTable` gains a header row and a
Created-by column as first-class parts. All call sites (`SubmissionsTable` `#Preview`,
`TripsOverviewDemoView`, `TripFormDemoView`) were updated to the new signature.

## States

| State | Trigger | Presentation |
|---|---|---|
| Default | Initial | Warning box, intro copy, 4 stub rows, single-page pagination, collapsed help, button |
| Help expanded | Tap disclosure | Status definitions revealed |
| Accessibility text sizes | Dynamic Type ≥ AX1 | Table wrapped in a horizontal `ScrollView` (reflow — see below) |

## Colours (mapped to `AppColors`)

| Element | Token |
|---|---|
| Header background | `govBlue` |
| Page title | `textPrimary` (black, bold — rendered via `TitleText`) |
| Warning box border + "Important" banner background | `govBlue` |
| Warning "Important" banner text | whiteed via `TitleText`) |
| Warning box border + "Important" banner background | `govBlue` |
| Warning "Important" banner text | white |
| Table header background | `surfaceMuted` |
| Table divider / border | `divider` |
| Date-cell link / pagination links | `linkText` (= `govBlue`) |
| Status tag backgrounds / text | `status*Background` / `status*Text` pairs |
| Primary button | `govGreen` (white text) |
| Body text | `textPrimary` |
| Showing-range / muted text | `textSecondary` |
| Screen background | `background` |

## Typography (`AppTypography`)

- Page title: `pageTitle` (bold, black, via `TitleText`)
- Warning "Important" banner
- Page title: `pageTitle` (bold, black, via `TitleText`)
- Warning "Important" banner
- Page caption title: `pageCaption`
- Warning tag / table headers: `bodySmall` (bold)
- Body & intro paragraphs: `body`
- Table cells / status tags / pagination: `bodySmall`
- Button: `button`

## Spacing (`AppSpacing`)

`large` between major blocks, `medium`/`small` within blocks, matching `ViewTemplate` padding.

## Accessibility annotations

- **Dynamic Type** to ≥200% — content scrolls (via `ViewTemplate`). See reflow strategy below.
- **VoiceOver** — warning box combined into "Important, &lt;message&gt;"; column headers marked
  `.isHeader`; date links labelled "View submission for &lt;date&gt;"; pagination container labelled
  "Pagination", controls labelled "Previous page"/"Next page"/"Page N", current page carries
  `.isSelected`; decorative chevrons `.accessibilityHidden(true)`.
- **Targets** ≥44×44pt — pagination controls and date links use a 44pt minimum frame.
- **Colour never the sole signal** — status is always conveyed by the status **text** (not colour
  alone).
- **Language of parts** (WCAG 3.1.2) — copy routed through `LocalizedText` / `languageStore.localized`
  so Welsh is pronounced under the Welsh locale.
- **Reduce Motion** respected — no non-essential animation added.

### Reflow strategy (chosen)

At **accessibility** Dynamic Type sizes (`dynamicTypeSize.isAccessibilitySize`) the 4-column table
would clip, so it is wrapped in a **horizontal `ScrollView`** with a sensible minimum width
(560pt), keeping the date link + status visible while the user scrolls across columns. At normal
sizes the table fills the available width as usual. This favours preserving all four columns over
dropping data.

### Contrast notes

- `govBlue` warning border/tag and `linkText` links on white background exceed AA for their sizes.
- `govGreen` white-on-green button exceeds 4.5:1.
- Status-tag foreground/background pairs (`status*Text` on `status*Background`) reuse the existing,
  previously-shipped tokens and were **not** modified. Computed WCAG 2.2 contrast ratios (sRGB
  relative luminance), all **PASS** AA for normal text (≥4.5:1):

  | Status tag | Text token | Background token | Ratio | Result |
  |---|---|---|---|---|
  | Submitted | `statusSubmittedText` | `statusSubmittedBackground` | 7.48:1 | PASS |
  | Amended | `statusAmendedText` | `statusAmendedBackground` | 8.44:1 | PASS |
  | Unsent | `statusUnsentText` | `statusUnsentBackground` | 8.41:1 | PASS |
  | Late | `statusLateText` | `statusLateBackground` | 8.59:1 | PASS |

  No token was required to change and none is knowingly broken. Any pair found below AA in a future
  audit should be flagged rather than silently shipped — none flagged in this delivery.

## Copy table (en / cy)

| Key | English | Welsh |
|---|---|---|
| `home.title` | Your trips | Eich teithiau _(needs_review)_ |
| `home.warning.tag` | Important | Pwysig |
| `home.warning.message` | The Catch Records service will be available from 1 October 2026. | Bydd y gwasanaeth Cofnodion Dalfa ar gael o 1 Hydref 2026. _(needs_review)_ |
| `home.intro.viewSubmitted` | View trips you've already submitted. | Gweld teithiau rydych chi eisoes wedi'u cyflwyno. _(needs_review)_ |
| `home.intro.selectDate` | Select an end date to see the details you recorded. | Dewiswch ddyddiad gorffen i weld y manylion a gofnodwyd gennych. _(needs_review)_ |
| `home.intro.webOnly` | Note: You can only add new trips and view your account settings on the web service, not in this app. | Sylwer: Dim ond ar y gwasanaeth gwe y gallwch ychwanegu teithiau newydd a gweld gosodiadau eich cyfrif, nid yn yr ap hwn. _(needs_review)_ |
| `home.table.header.endDate` | Trip end date | Dyddiad gorffen y daith _(needs_review)_ |
| `home.table.header.vessel` | Vessel | Llong _(needs_review)_ |
| `home.table.header.status` | Status | Statws _(needs_review)_ |
| `home.table.header.createdBy` | Created by | Crëwyd gan _(needs_review)_ |
| `home.pagination.previous` | Previous | Blaenorol _(needs_review)_ |
| `home.pagination.next` | Next | Nesaf _(needs_review)_ |
| `home.pagination.showing` | Showing %1$@ to %2$@ of %3$@ | Yn dangos %1$@ i %2$@ o %3$@ _(needs_review)_ |
| `home.pagination.page` | Page %@ | Tudalen %@ _(needs_review)_ |
| `home.pagination.a11y.container` | Pagination | Tudalennu _(needs_review)_ |
| `home.pagination.a11y.previous` | Previous page | Tudalen flaenorol _(needs_review)_ |
| `home.pagination.a11y.next` | Next page | Tudalen nesaf _(needs_review)_ |
| `home.table.viewSubmission` | View submission for %@ | Gweld y cyflwyniad ar gyfer %@ _(needs_review)_ |
| `home.help.title` | Understanding catch record statuses | Deall statysau cofnodion dalfa _(needs_review)_ |
| `home.help.unsent.heading` | Unsent: | Heb ei anfon: _(needs_review)_ |
| `home.help.unsent.description` | Saved on your device and not yet submitted. | Wedi'i gadw ar eich dyfais ac heb ei gyflwyno eto. _(needs_review)_ |
| `home.help.submitted.heading` | Submitted: | Cyflwynwyd: _(needs_review)_ |
| `home.help.submitted.description` | Received by the MMO. | Derbyniwyd gan yr MMO. _(needs_review)_ |
| `home.help.amended.heading` | Amended: | Diwygiwyd: _(needs_review)_ |
| `home.help.amended.description` | This record was changed after it was submitted. | Newidiwyd y cofnod hwn ar ôl iddo gael ei gyflwyno. _(needs_review)_ |
| `home.help.late.heading` | Late: | Hwyr: _(needs_review)_ |
| `home.help.late.description` | This record was received by the MMO after the required reporting timeframe. | Derbyniwyd y cofnod hwn gan yr MMO ar ôl yr amserlen adrodd ofynnol. _(needs_review)_ |
| `home.createRecord.button` | Create a new catch record | Creu cofnod dalfa newydd _(needs_review)_ |
| `home.howToRecord.title` | How to record a catch | Sut i gofnodi dalfa _(needs_review)_ |
| `home.howToRecord.whatYouNeedToDo.heading` | What you need to do | Beth sydd angen i chi ei wneud _(needs_review)_ |
| `home.howToRecord.whatYouNeedToDo.body1` | You must record all catches unless an exemption applies. | Rhaid i chi gofnodi pob dalfa oni bai bod eithriad yn berthnasol. _(needs_review)_ |
| `home.howToRecord.whatYouNeedToDo.body2` | We'll ask whether you caught any species subject to catch limits (quota). | Byddwn yn gofyn a wnaethoch ddal unrhyw rywogaethau sy'n ddarostyngedig i derfynau dalfa (cwota). _(needs_review)_ |
| `home.howToRecord.whenToCreate.heading` | When to create your record | Pryd i greu eich cofnod _(needs_review)_ |
| `home.howToRecord.whenToCreate.intro` | Create your catch record before moving your catch off the vessel if you: | Crëwch eich cofnod dalfa cyn symud eich dalfa oddi ar y llong os ydych chi: _(needs_review)_ |
| `home.howToRecord.whenToCreate.bullet.quota` | caught any species subject to catch limits (quota) | wedi dal unrhyw rywogaethau sy'n ddarostyngedig i derfynau dalfa (cwota) _(needs_review)_ |
| `home.howToRecord.whenToCreate.bullet.nonQuota` | caught only non-quota species | wedi dal rhywogaethau di-gwota yn unig _(needs_review)_ |
| `home.howToRecord.whenToCreate.bullet.icesBoundary` | crossed an ICES area boundary while fishing | wedi croesi ffin ardal ICES wrth bysgota _(needs_review)_ |
| `home.howToRecord.whenToCreate.deadline` | You need to create your catch record within 24 hours of landing your catch. | Mae angen i chi greu eich cofnod dalfa o fewn 24 awr i lanio eich dalfa. _(needs_review)_ |
| `home.howToRecord.icesAreas.heading` | Special cases: ICES areas | Achosion arbennig: ardaloedd ICES _(needs_review)_ |
| `home.howToRecord.icesAreas.body1` | If you fish in or cross ICES areas 4c, 7d or 7e, you must create a separate catch record each time you cross a boundary. | Os ydych chi'n pysgota yn ardaloedd ICES 4c, 7d neu 7e neu'n eu croesi, rhaid i chi greu cofnod dalfa ar wahân bob tro y byddwch yn croesi ffin. _(needs_review)_ |
| `home.howToRecord.icesAreas.body2` | If you need to record catches without an internet connection, use the mobile app. | Os oes angen i chi gofnodi dalfeydd heb gysylltiad rhyngrwyd, defnyddiwch yr ap symudol. _(needs_review)_ — **content flag**: reads oddly on a screen that *is* the mobile app; see note above. |
| `home.howToRecord.getHelp.heading` | Get help with your record | Cael help gyda'ch cofnod _(needs_review)_ |
| `home.howToRecord.getHelp.phone` | Call 0300 020 3788, Monday to Friday, 9am to 5pm. | Ffoniwch 0300 020 3788, dydd Llun i ddydd Gwener, 9am i 5pm. _(needs_review)_ |
| `home.howToRecord.getHelp.callCost` | Calls to 03 numbers cost the same as calls to 01 or 02 numbers. | Mae galwadau i rifau 03 yn costio'r un fath â galwadau i rifau 01 neu 02. _(needs_review)_ |
| `home.howToRecord.getHelp.outOfHours` | Outside these hours, leave a catch record on our automated line. | Y tu allan i'r oriau hyn, gadewch gofnod dalfa ar ein llinell awtomataidd. _(needs_review)_ |

Welsh strings needing confirmation by a Welsh speaker are tracked via the String Catalog
`state: needs_review` plus a translator `comment` — never via a user-visible `[CY-TODO]` prefix.

## Accessibility identifier notes

| Identifier | Element |
|---|---|
| `Home.warningBox` | Warning box (combined element) |
| `Home.pagination.previous` | Previous control (hidden on first/only page) |
| `Home.pagination.next` | Next control (hidden on last/only page) |
| `Home.pagination.page.<n>` | Page number control |
| `Home.pagination.showing` | Showing-range text |
| `Home.createRecordButton` | Primary "Create a new catch record" button |
| `Home.table.row.<n>.date` | Table date-cell link for row `n` |
| `Home.howToRecord` | "How to record a catch" disclosure button |
| `Home.statusHelp` | "Understanding catch record statuses" disclosure button |

Table date-cell links are addressed in tests via their stable accessibility **identifier**
(`Home.table.row.<n>.date`); the user-facing accessibility **label** ("View submission for &lt;date&gt;")
is localised via `home.table.viewSubmission` so it is pronounced correctly under the Welsh locale.

## Hosting note

The default app root stays `SignInView`. A `-uiTestHome` launch argument in
`App/record_catchApp.swift` shows `HomeView` instead (injecting `AppLanguageStore` + locale exactly
as the current root does) for lightweight UI-test hosting. `ContentView` / the SwiftData template is
untouched.
