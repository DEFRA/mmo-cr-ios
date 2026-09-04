# ADR 0011 — Release (CD) pipeline: Fastlane on GitHub Actions, DEV increment

- Status: Accepted
- Date: 2026-08
- Deciders: iOS engineering / DevOps
- Context tags: ci-cd, github-actions, fastlane, testflight, code-signing, match, native-iOS

## Context

[ADR-0008](0008-ci-pipeline.md) delivered PR-validation CI and left the release pipeline (signing,
TestFlight/App Store, gated GitHub Environments, versioning) as a separate future change. The DevOps
delivery design freezes a single tag-triggered release workflow with six sequential, individually gated
jobs across six GitHub Environments (`dev` … `prod-appstore`), building three per-environment
apps (`mmo.catchrecordingdev.ios` / `mmo.catchrecordingtest.ios` / `mmo.catchrecording.ios`) from one
tagged commit.

The full topology depends on artefacts that do not yet exist: the test/prod bundle IDs, the per-environment
`.xcconfig`/schemes, the Test/Prod App Store Connect app records, signing assets and the gated
Environments/secrets. This ADR therefore covers **two things now**: (1) moving CI build+test back onto
Fastlane, and (2) the **DEV-only** first increment of the release pipeline. Test/Prod build,
external-TestFlight promotion and App Store submission are explicitly deferred.

## Decision

### 1. CI build and test run through Fastlane

[.github/workflows/ios-ci.yml](../../.github/workflows/ios-ci.yml) no longer calls `xcodebuild` directly.
It sets up Ruby/Bundler (`ruby/setup-ruby`, `bundler-cache: true`) and runs `bundle exec fastlane build`
then `bundle exec fastlane test`. The Fastfile gains a self-contained `build` lane
(`run_tests(build_for_testing: true)`, UI tests skipped) as the compile gate, alongside the existing
`test` lane (unit tests + coverage + result bundle). The SonarCloud step locates the produced
`fastlane/test_output/*.xcresult` and converts coverage as before. This keeps one automation model shared
with the release pipeline.

### 2. Release workflow — DEV increment

New [.github/workflows/ios-release.yml](../../.github/workflows/ios-release.yml):

- Triggers on `v*` tags (plus `workflow_dispatch` with mandatory `marketing_version` and `project_version` inputs).
- **Non-cancelling** concurrency so an in-flight release is never auto-cancelled.
- Least-privilege `permissions: contents: read`.
- A single `dev-build-internal` job on the ungated `dev` GitHub Environment, which scopes the Dev
  App Store Connect and signing secrets to this job only.
- Marketing version is sourced from the Xcode project's `MARKETING_VERSION` (single source of truth,
  see decision 3a); the build number defaults to `GITHUB_RUN_NUMBER` on tag triggers, or the mandatory `project_version` input for `workflow_dispatch`.

### 3. Fastlane `release_dev` lane

`release_dev` calls a parametrised private `build_and_upload` lane (so future test/prod lanes reuse it):

- App Store Connect **API-key** auth from `ASC_KEY_ID` / `ASC_ISSUER_ID` / `ASC_KEY_CONTENT` (base64).
- **Signing (POC):** a manual `.p12` certificate + DEV provisioning profile imported into a temporary
  keychain by the workflow; the `match` call is commented out (see decision 4).
- `build_app` (app-store export) with only `CURRENT_PROJECT_VERSION` passed as an `xcarg` — the
  `MARKETING_VERSION` baked into `project.pbxproj` is used unchanged (decision 3a) — so the
  **tagged commit is built unchanged** (no project mutation).
- `upload_to_testflight(distribute_external: false)` → the Dev app's internal TestFlight group.

### 3a. Marketing version — project.pbxproj is the single source of truth (tag validated against it)

The Xcode project's `MARKETING_VERSION` (`record-catch.xcodeproj/project.pbxproj`, app target
`mmo.catchrecordingdev.ios`) is the **single source of truth** for the marketing version, not the git tag.
A "Validate tag matches project MARKETING_VERSION" step in `ios-release.yml` reads the app target's
`MARKETING_VERSION` (guarding against the test targets' unrelated `MARKETING_VERSION = 1.0`) and validates
it against the triggering event: for a `v*` tag push it fails the job with `::error::` if the tag does not
equal it; for `workflow_dispatch` the `marketing_version` input is **mandatory** (`required: true`, no
default) and is always validated against the project value, regardless of which branch the run was
dispatched from — the guard keys off `github.event_name`, not `github.ref`, so it behaves consistently for
manual runs from any branch. This is a deliberate deviation from the
ci-cd standard's "derive marketing version from the tag" preference (see
[ci-cd instructions](../../.github/instructions/ci-cd.instructions.md)), chosen for this DEV POC so the
Xcode project remains the single source of truth for the version baked into the app; the team should log
this deviation with Delivery Architecture (delivery.architecture@defra.gov.uk) if it should be formally
recorded.

### 4. Signing — Fastlane Match (target) with a manual `.p12` POC deviation for DEV

Fastlane Match (read-only, per design §8.2) is the **target** signing approach. **For the initial DEV
proof-of-concept, however, the pipeline signs with a manual `.p12` certificate + provisioning profile
(design §8.3), bypassing Match**: the release workflow decodes the certificate and profile from secrets,
imports them into a **temporary keychain** on the runner (deleted at job end), and `build_app` signs
manually (`CODE_SIGN_STYLE=Manual` with the DEV distribution profile). The `match(...)` call in the
`build_and_upload` lane is **commented out, not removed**, so the full test/prod rollout can switch back to
Match without rework. Only the release job receives signing secrets; PR CI never does.

## Consequences

- The Dev release path exists as reviewable, version-controlled pipeline-as-code and extends ADR-0008’s
  single automation model.
- **Prerequisites before this workflow can run green** (provisioning, not code): the `dev` Environment
  with the App Store Connect API-key secrets `ASC_KEY_ID` / `ASC_ISSUER_ID` / `ASC_KEY_CONTENT`, and — for
  the manual `.p12` POC — `BUILD_CERTIFICATE_BASE64`, `P12_PASSWORD`, `BUILD_PROVISION_PROFILE_BASE64`,
  `KEYCHAIN_PASSWORD`, `APPLE_TEAM_ID` and `PROVISIONING_PROFILE_NAME`; plus the Dev App Store Connect app
  record with an internal TestFlight group. (The `MATCH_*` secrets are not needed while the POC bypasses
  Match.)
- **Follow-ups (out of scope here):** the three `.xcconfig`/schemes and test/prod identities (iOS
  Developer app-code work); embedding `GitCommitSHA` as read-only `Info.plist` metadata (needs an
  `Info.plist` key wired in the project); the remaining `test`/`prod` build, external-promotion and App
  Store jobs with their gated Environments (Approvals A–E); and — as flagged in ADR-0008 — pinning
  Actions to full commit SHAs before this is relied on for real release engineering.
- Xcode Cloud was considered and not adopted for release; GitHub Actions + Fastlane remains the sole
  orchestrator (design §3).
