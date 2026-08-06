# Design Spec — Sign In (UI only)

Feature: bilingual Sign In screen for the DEFRA / MMO Catch Recording iOS app.
Scope: **UI only**. No real auth, networking, Keychain, OIDC or offline/sync. The credential
error is a **stubbed presentational flag** for demonstrating the error state.

## Layout (inside `ViewTemplate`)

The screen renders via `ViewTemplate(title:) { content }`, so it inherits the shared
`ViewHeader` (Back / GOV.UK / language toggle), a page caption title, the scrollable content
area and `ViewFooter`. Content, top to bottom:

1. **Credential error summary** (only when `showInvalidCredentials`): red bordered region at the
   top of content, SF Symbol `exclamationmark.circle.fill` + message. Announced to VoiceOver.
2. **Heading** — "Sign in" (`SignIn.heading`).
3. **Email field** — `TextInputField`, keyboard `.emailAddress`, no autocapitalisation/autocorrect,
   content type `.username` (`SignIn.emailField`). Inline error below when empty after submit.
4. **Password field** — `TextInputField` secure with show/hide toggle, content type `.password`.
   `TextInputField` is a composite, so an outer `SignIn.passwordField` identifier is swallowed by the
   inner secure input. The password field is therefore addressed in tests via the inner
   `TextInputField.secureInput` / `TextInputField.secureToggle` identifiers (no `SignIn.passwordField`).
   Inline error below when empty after submit.
5. **Sign in** — green `PrimaryButton` (`SignIn.signInButton`).
6. **"Having trouble signing in?"** secondary heading (`SignIn.troubleHeading`).
7. Two **inert link-styled buttons**: "Forgotten your password?" (`SignIn.forgottenPasswordLink`)
   and "Create an account" (`SignIn.createAccountLink`). They navigate nowhere in this phase.

## States

| State | Trigger | Presentation |
|---|---|---|
| Default | Initial | Fields empty, no errors, no summary |
| Field validation error | `submit()` with an empty email and/or password | Inline red text + icon under each empty field; VoiceOver "Error:" / "Gwall:" prefix |
| Stubbed credential error | `submit()` when both fields filled (stub) | Top summary region shows generic credential error; announced |

## Colours (mapped to `AppColors`)

| Element | Token |
|---|---|
| Header background | `govBlue` |
| Page caption title | `govBlue` |
| Primary button | `govGreen` (white text) |
| Error text / icon / borders | `errorRed` |
| Body text | `textPrimary` |
| Secondary / muted text | `textSecondary` |
| Screen background | `background` |
| Links | `linkText` (= `govBlue`) |

## Typography (`AppTypography`)

- Page title/caption: `pageCaption`
- Section headings: `pageTitle` (heading) / `footerHeading` (trouble heading)
- Body & field labels: `body` / `fieldLabel`
- Errors: `error`
- Button: `button`

## Spacing (`AppSpacing`)

Vertical rhythm uses `large` between major blocks, `medium`/`small` within blocks, matching
`ViewTemplate`'s existing padding.

## Accessibility annotations

- **Dynamic Type** to ≥200% — content scrolls (via `ViewTemplate`).
- **Contrast** ≥4.5:1 via `AppColors` tokens (see contrast notes below).
- **Targets** ≥44×44pt — `PrimaryButton`, secure toggle and language toggle all meet this.
- **VoiceOver** — every field/link/button/toggle has a label; errors announced with a hidden
  "Error:" / "Gwall:" prefix; credential summary uses an alert-like announcement.
- **Language of parts** (WCAG 3.1.2) — Welsh content presented under the Welsh locale so VoiceOver
  pronounces it correctly.
- **Reduce Motion** respected — no non-essential animation is added.
- **Colour is never the only signal** — errors combine colour + icon + text.

### Contrast notes

`errorRed` (GDS `#D4351C`) on white ≈ 4.6:1 — meets AA for normal text. `govGreen`
white-on-green and `govBlue` white text both exceed 4.5:1. No token is knowingly broken; any that
fails AA is flagged in the delivery report rather than silently shipped.

## Copy table (en / cy)

| Key | English | Welsh |
|---|---|---|
| `signIn.title` | Sign in | Mewngofnodi |
| `signIn.heading` | Sign in | Mewngofnodi |
| `signIn.email.label` | Email address | Cyfeiriad e-bost |
| `signIn.password.label` | Password | Cyfrinair |
| `signIn.button` | Sign in | Mewngofnodi |
| `signIn.error.email.empty` | Enter your email address | Rhowch eich cyfeiriad e-bost |
| `signIn.error.password.empty` | Enter your password | Rhowch eich cyfrinair |
| `signIn.error.credentials` | The email address or password you entered is incorrect | Mae'r cyfeiriad e-bost neu'r cyfrinair a roddwyd gennych yn anghywir _(needs_review)_ |
| `signIn.trouble.heading` | Having trouble signing in? | Cael trafferth mewngofnodi? |
| `signIn.link.forgottenPassword` | Forgotten your password? | Wedi anghofio'ch cyfrinair? |
| `signIn.link.createAccount` | Create an account | Creu cyfrif |
| `a11y.errorPrefix` | Error: | Gwall: |
| `header.back` | Back | Yn ôl |
| `header.branding` | GOV.UK | GOV.UK |
| `header.language.toWelsh` | Cymraeg | Cymraeg |
| `header.language.toEnglish` | English | English |
| `header.language.hint.toWelsh` | Switch to Welsh | Newid i'r Gymraeg |
| `header.language.hint.toEnglish` | Switch to English | Newid i'r Saesneg |

Welsh strings needing confirmation by a Welsh speaker are tracked via the String Catalog
`state: needs_review` plus a translator `comment` — never via a user-visible `[CY-TODO]` prefix in the
rendered value. `signIn.error.credentials` (cy) currently remains `needs_review`.

## Accessibility identifier note

The password field reuses the existing `TextInputField` identifiers
(`TextInputField.secureInput` for the secure field, `TextInputField.secureToggle` for the
show/hide toggle) rather than a composite `SignIn.passwordField`. Applying a composite identifier
to a secure `TextInputField` collapses its children in the accessibility tree, which would both
hide the `SecureTextField` from XCUITest and break the pre-existing
`SecureTextInputFieldUITests`. The plan explicitly permits reusing the existing secure-field
identifiers, so we do. All other listed identifiers are present as specified.
