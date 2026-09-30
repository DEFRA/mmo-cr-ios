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

### 2. One backend URL, injected at build time, never in git

- A partial `Info.plist` adds one custom key: `MMOAPIBaseURL = $(MMO_API_BASE_URL)`. Xcode merges it with the
  generated plist.
- In CI, `MMO_API_BASE_URL` is a **GitHub Environment variable** (not a secret — it is not sensitive and must be
  auditable). The workflow maps it into the job environment; Fastlane validates it (present, `https://`) and
  passes it to Xcode as a command-line build setting (`xcargs`). Command-line settings avoid the xcconfig
  gotcha where `//` in `https://` starts a comment.
- Locally, developers use an optional, git-ignored `Config/Local.xcconfig` pulled in with `#include?`. Inside an
  xcconfig a URL must be written as `https:/$()/host` because of the same `//` rule.

### 3. App behaviour (owned by the iOS Developer)

- Read `MMOAPIBaseURL` once at startup; if missing or not `https://`, show a clear configuration error and log
  it — never fall back to another backend.
- Log on every launch: backend URL, bundle ID, version, build, commit SHA (URL is non-sensitive and logged as
  public).
- Partition local data (store + Keychain service) by backend URL so data from one backend can never be sent to
  another.

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
