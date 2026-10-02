# ADR 0014 — Build-time app identity configuration (three apps, backend URL injected from CI)

- Status: Accepted
- Date: 2026-09
- Deciders: iOS engineering / DevOps
- Context tags: ci-cd, configuration, bundle-id, xcconfig, fastlane, github-environments
- Related: [ADR-0011](0011-release-pipeline.md) (amended), [ADR-0015](0015-compile-once-configure-at-promotion.md)

## Context

The app ships as three App Store Connect apps — `mmo.catchrecordingdev.ios`, `mmo.catchrecordingtest.ios` and
`mmo.catchrecording.ios` — but the repository hard-codes the Dev identity in 11 places across the Xcode project,
Fastlane (`Appfile`, `Fastfile`, `Matchfile`), the release-tag scripts and docs. The app also has no backend URL
configuration yet (`AppEnvironment` is an empty placeholder).

Backend URLs must **not** be committed to git; they are supplied per stage by GitHub Environment variables.

## Decision

### 1. One identity per Xcode configuration, driven by `.xcconfig`

- `Config/Base.xcconfig` holds shared settings, including `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`
  (single source of truth for versions — amends ADR-0011 §3a).
- `Config/Dev.xcconfig`, `Config/Test.xcconfig`, `Config/Prod.xcconfig` each `#include "Base.xcconfig"` and set
  only what differs: `APP_BUNDLE_ID`, `APP_DISPLAY_NAME`.
- Build configurations `Debug-Dev/Release-Dev`, `Debug-Test/Release-Test`, `Debug-Prod/Release-Prod` map to those
  files; three **shared** schemes `record-catch-Dev`, `record-catch-Test`, `record-catch-Prod`.
- The app target sets `PRODUCT_BUNDLE_IDENTIFIER = $(APP_BUNDLE_ID)`. The existing **target-level literal must be
  replaced, not supplemented** — Apple's precedence is target level > xcconfig mapped to target > project level,
  so a leftover literal silently wins.
- Test targets keep their own identifiers; they are never distributed.

### 2. Stage configuration from GitHub Environment variables, never in git (amended 2026-10)

The original single key (`MMOAPIBaseURL` from `MMO_API_BASE_URL`) is replaced by a generic mechanism, so new
stage values need no workflow change.

- **Variables only.** Any GitHub Environment *variable* named `CR_APP_CFG_<KEY>` is a candidate app value; the
  workflow passes all variables to Fastlane as `CR_APP_CFG_VARS: ${{ toJSON(vars) }}`. GitHub *secrets* are never
  mapped: everything in the package can be extracted (OWASP MASWE-0004).
- **Committed allow-list.** `Config/app-config.schema.json` declares each `<KEY>` with `type` (`url`, `string`,
  `bool`), `required`, `log` and a description. A CI check rejects secret-like names (`SECRET`, `PASSWORD`,
  `TOKEN`, `PRIVATE`, `CREDENTIAL`) and `url` keys marked `tracking: true`: tracking domains must be compiled into
  the privacy manifest, not configured per stage (MASWE-0074).
- **Validation in Fastlane.** Required keys must be present; `url` values must be `https://` with a host and no
  user/password; `string` values one line, at most 512 characters; `bool` values `true`/`false`. Undeclared
  `CR_APP_CFG_*` variables are warned about and ignored, so an older tag still releases after new variables are
  added. Only `log: true` keys are printed.
- **One `Info.plist` dictionary, `MMOCRAppConfig`,** written after archiving (`plutil -replace MMOCRAppConfig
  -json`) at build (`N`) and again at promotion (`N.1`) — one code path, typed values, no escaping issues. The
  name avoids Apple-reserved prefixes.
- **Per Environment only.** `CR_APP_CFG_*` must never be set at repository or organisation level: GitHub
  precedence would silently apply such a value to every stage.
- **Flags are fixed at packaging.** The App Store package is exactly what Apple reviews; this mechanism must never
  be used for runtime or remote feature switching (App Review Guideline 2.3.1).
- **Local development:** a partial `Info.plist` template maps `MMOCRAppConfig` entries to `$(CR_APP_CFG_<KEY>)`,
  supplied by an optional, git-ignored `Config/Local.xcconfig` (`#include?`); URLs there are written
  `https:/$()/host` because `//` starts an xcconfig comment. Xcode ignores user-defined settings when *generating*
  `Info.plist`, so the template file is required, and it must not be a member of the target.

### 3. App behaviour (owned by the iOS Developer)

- Read `MMOCRAppConfig` once at startup through one `AppConfiguration` type; if a required key is missing or
  invalid, show a clear configuration error and log it — never fall back to another backend.
- Log on every launch the `log: true` values (non-sensitive, logged as public), plus bundle ID, version, build
  and commit SHA.
- Partition local data (store + Keychain service) by `API_BASE_URL` so data from one backend can never be sent to
  another.
- Treat configuration as untrusted for security decisions: a modified package can change it, so the backend
  enforces authorisation (server-side App Attest remains optional, ADR-0015).

### 4. Fastlane has one identity table

The Fastfile maps an app key (`dev`/`test`/`prod`) to scheme, configuration and xcconfig, and reads
`APP_BUNDLE_ID` from that xcconfig rather than repeating it. The `Matchfile` lists all three identities (Match
needs them explicitly); `Appfile` drops its hard-coded identifier.

## Consequences

- One declarative place per identity; the same codebase builds all three apps.
- `project.pbxproj` changes are merge-conflict prone — land them as one small PR.
- The release-tag scripts must read versions from `Base.xcconfig` (via Fastlane) once it lands; their current
  `awk` anchor on the Dev bundle-ID literal breaks the moment the literal is removed.
- Test and Prod App IDs must be registered, their App Store Connect records created, and Match profiles added for
  all three identities before those apps can be released.
- **Ownership:** `Config/*`, schemes, the partial `Info.plist` and the app-side items in §3 are iOS Developer work;
  Fastlane, workflows, scripts and signing are DevOps work.
