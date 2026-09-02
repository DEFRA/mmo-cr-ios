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

- Triggers on `ios-v*` tags (plus `workflow_dispatch` with a `marketing_version` input for dry runs).
- **Non-cancelling** concurrency so an in-flight release is never auto-cancelled.
- Least-privilege `permissions: contents: read`.
- A single `dev-build-internal` job on the ungated `dev` GitHub Environment, which scopes the Dev
  App Store Connect and Match secrets to this job only.
- Marketing version is derived from the tag (`ios-v1.4.0` → `1.4.0`); the build number is the
  `GITHUB_RUN_NUMBER`.

### 3. Fastlane `release_dev` lane

`release_dev` calls a parametrised private `build_and_upload` lane (so future test/prod lanes reuse it):

- App Store Connect **API-key** auth from `ASC_KEY_ID` / `ASC_ISSUER_ID` / `ASC_KEY_CONTENT` (base64).
- **Fastlane Match, read-only** (`type: "appstore"`, `readonly: true`) for signing — the preferred design
  approach; the encrypted store is provisioned out of band.
- `build_app` (app-store export) with `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` passed as `xcargs`,
  so the **tagged commit is built unchanged** (no project mutation).
- `upload_to_testflight(distribute_external: false)` → the Dev app's internal TestFlight group.

### 4. Signing = Fastlane Match (read-only)

Per design §8.2, in preference to manual `.p12` injection. Only the release job receives signing secrets;
PR CI never does.

## Consequences

- The Dev release path exists as reviewable, version-controlled pipeline-as-code and extends ADR-0008’s
  single automation model.
- **Prerequisites before this workflow can run green** (provisioning, not code): the `dev`
  Environment with `ASC_KEY_ID`/`ASC_ISSUER_ID`/`ASC_KEY_CONTENT` and `MATCH_GIT_URL`/`MATCH_PASSWORD`/
  `MATCH_GIT_BASIC_AUTHORIZATION` secrets; a Match store holding the Dev `appstore` profile; and the Dev
  App Store Connect app record with an internal TestFlight group.
- **Follow-ups (out of scope here):** the three `.xcconfig`/schemes and test/prod identities (iOS
  Developer app-code work); embedding `GitCommitSHA` as read-only `Info.plist` metadata (needs an
  `Info.plist` key wired in the project); the remaining `test`/`prod` build, external-promotion and App
  Store jobs with their gated Environments (Approvals A–E); and — as flagged in ADR-0008 — pinning
  Actions to full commit SHAs before this is relied on for real release engineering.
- Xcode Cloud was considered and not adopted for release; GitHub Actions + Fastlane remains the sole
  orchestrator (design §3).
