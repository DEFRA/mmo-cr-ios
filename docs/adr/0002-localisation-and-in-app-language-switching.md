# ADR 0002 — Localisation and in-app language switching (English / Welsh)

- Status: Accepted
- Date: 2026-07
- Deciders: iOS engineering
- Context tags: localisation, accessibility, Welsh Language Standards

## Context

DEFRA / MMO services must be available in **Welsh** as well as English (Welsh Language Standards;
GOV.UK bilingual guidance). Fishers must be able to **switch language in-app** (a header toggle),
and the choice must **persist across launches**. The switch must take effect **without an app
restart** and must be correct for **VoiceOver pronunciation** (WCAG 3.1.2 Language of Parts).

## Decision

### 1. String Catalog (`Localizable.xcstrings`)

Use a single **String Catalog** (`record-catch/Resources/Localizable.xcstrings`) as the source of
truth for UI copy. Development language is **English (`en`)**; **Welsh (`cy`)** is added as a second
language. The project already sets `LOCALIZATION_PREFERS_STRING_CATALOGS = YES` and
`SWIFT_EMIT_LOC_STRINGS = YES`, so `LocalizedStringKey` references resolve against the catalog.
Uncertain Welsh translations are flagged inline with a `[CY-TODO]` prefix and a translator comment
so a Welsh speaker can complete them; they are never guessed silently. These markers live only in the
translator `comment` and `state: needs_review` — never in a user-visible `value`.

### 2. In-app language switch mechanism

App-level `selectedLanguage` state (`enum AppLanguage { .english, .welsh }`) is persisted with
`@AppStorage("app.language")` and injected at the app root.

### 3. The iOS 16 pitfall (why `.environment(\.locale)` alone is not enough)

On iOS 16, setting `.environment(\.locale, Locale(identifier: "cy"))` updates locale-driven
formatting (dates, numbers) **but does not re-resolve String Catalog / `LocalizedStringKey`
lookups** — those resolve against the *app's* preferred localisation, which is fixed at launch.
Toggling the environment locale alone leaves visible copy in the original language until the app is
relaunched.

**Mitigation:** resolve strings explicitly from the **selected-language `.lproj` bundle**. We add a
small helper (`LocalizedBundle` / `AppLanguage.localized(_:)`) that loads the correct
`Bundle(path:.../<code>.lproj)` and calls `NSLocalizedString(_, bundle:)` (which reads the compiled
String Catalog). A thin `LocalizedText` view wraps this so views stay declarative.

Setting `.environment(\.locale, …)` alone updates formatting but does **not** set the pronunciation
language for a `Text` built from a runtime `String`. So for **language of parts** (WCAG 3.1.2)
`LocalizedText` renders the resolved copy as an `AttributedString` carrying
`.languageIdentifier(<code>)`, which VoiceOver uses to pronounce Welsh content correctly. The
environment locale is still set at the root so date/number formatting follows the selection.

### 4. `[CY-TODO]` markers are comment-only

Uncertain Welsh translations are flagged via the String Catalog `state: needs_review` plus a
translator `comment`. A `[CY-TODO]` marker must **never** appear in a user-visible `value` (it would
render on screen); such markers live only in the `comment` field.

## Consequences

- Language changes apply live, without a restart, on iOS 16+.
- One extra indirection (bundle lookup) for user-facing copy; encapsulated in a helper and tested.
- Welsh copy completeness is auditable via `state: needs_review` and translator `comment`s (no
  user-visible `[CY-TODO]` markers).
