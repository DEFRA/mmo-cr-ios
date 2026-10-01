# Release environments — per-environment setup and runbook

> **PROVISIONAL.** The backend ↔ app mapping below is the working model and has **not yet been confirmed**.
> Do not provision App Store Connect records or GitHub Environments from this page until the mapping is
> confirmed and this banner is removed. See [Revisit when the mapping is confirmed](#revisit-when-the-mapping-is-confirmed).

Decisions: [ADR-0014](../adr/0014-build-time-app-identity-configuration.md) (identity + backend URL injection),
[ADR-0015](../adr/0015-compile-once-configure-at-promotion.md) (compile once, configure at promotion),
[ADR-0011](../adr/0011-release-pipeline.md) (release pipeline). Signing: [fastlane-match-signing.md](fastlane-match-signing.md).

## Mapping

| App (bundle ID) | Channel | Backend | Build | Users | GitHub Environment (gate) | Workflow · job |
|---|---|---|---|---|---|---|
| Dev (`mmo.catchrecordingdev.ios`) | Internal TestFlight | Dev | `N` | Dev team | `dev` (none) | `ios-release` · `dev-build` |
| Dev | External TestFlight (**demo of the promotion path**) | set in `dev_external` | `N.1` | Dev team | `dev_external` (reviewer) | `ios-release` · `dev-promote-external` |
| Test (`mmo.catchrecordingtest.ios`) | Internal TestFlight | Test | `N` | Project QA — sprint testing | `test` (A) | `ios-release` · `test-build` |
| Test | External TestFlight | Perf-Test | `N.1` | Project QA + perf — release testing, RC sign-off | `test-external` (B) | `ios-promote` · `test-promote-external` |
| Prod (`mmo.catchrecording.ios`) | Internal TestFlight | Ext-Test | `N` | MMO QA — UAT | `prod` (C) | `ios-release` · `prod-build` |
| Prod | External TestFlight | Prod | `N.1` | Sanity | `prod-external` (D) | `ios-promote` · `prod-promote-external` |
| Prod | App Store | Prod | same `N.1` | Public | `prod-appstore` (E) | `ios-promote` · `prod-appstore-submit` |

A tester belongs to an app's internal **or** external group, never both, and uninstalls to switch. Tester
assignment to groups is managed outside the pipeline.

## One-off setup per app (Apple)

| Step | Dev | Test | Prod |
|---|---|---|---|
| App ID registered in the Apple Developer portal | Done | To do | To do |
| App Store Connect app record | Done | To do | To do |
| Internal TestFlight group (members need App Store Connect roles; max 100) | Done | To do | To do |
| External TestFlight group(s) + Beta App Review information | n/a | To do | To do |
| App Store listing, privacy details, phased release | n/a | n/a | To do |
| Match App Store profile ([signing runbook](fastlane-match-signing.md#part-b--add-a-new-app-to-the-store-test-prod), Part B) | Done | To do | To do |

## One-off setup per GitHub Environment

Every Environment: **deployment branches and tags** restricted to `main` and `v*`; the reviewers below with
**prevent self-review** on; **admin bypass disabled** for `prod-appstore`.

| Environment | Required reviewers | Variable `MMO_API_BASE_URL` | Secrets |
|---|---|---|---|
| `dev` | none | Dev backend URL | `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_CONTENT`, `APPLE_TEAM_ID`, `MATCH_PASSWORD`, `MATCH_DEPLOY_KEY`, `ARCHIVE_ENCRYPTION_KEY` |
| `dev_external` | At least one reviewer (demonstrates the gate) | External-demo backend URL | as `dev` (same `ARCHIVE_ENCRYPTION_KEY`), plus `ASC_EXTERNAL_TESTING_GROUPS` |
| `test` | Approver A | Test backend URL | ASC key trio, `APPLE_TEAM_ID`, `MATCH_PASSWORD`, `MATCH_DEPLOY_KEY`, `ARCHIVE_ENCRYPTION_KEY` |
| `test-external` | Approver B | Perf-Test backend URL | as `test` (same `ARCHIVE_ENCRYPTION_KEY`), plus `ASC_EXTERNAL_TESTING_GROUPS` |
| `prod` | Approver C | Ext-Test backend URL | as `test`, with its **own** `ARCHIVE_ENCRYPTION_KEY` |
| `prod-external` | Approver D | Prod backend URL | as `prod` (same `ARCHIVE_ENCRYPTION_KEY`), plus `ASC_EXTERNAL_TESTING_GROUPS` |
| `prod-appstore` | Approver E (business/release) | — | ASC key trio only |

- URLs are **variables, never secrets and never in git**. Each must be `https://` with a publicly trusted
  certificate (ATS).
- `ARCHIVE_ENCRYPTION_KEY`: generate with `openssl rand -base64 32`; the build Environment and its promotion
  Environment must hold the **same** value (`dev`/`dev_external`, `test`/`test-external`, `prod`/`prod-external`);
  Dev, Test and Prod use **different** values. Store it in the team credential store.
- `dev_external` exists to demonstrate the approval gate and the no-recompile promotion on the Dev app before Test
  and Prod are set up. If its URL equals the `dev` URL the internal-host leak check is skipped with a warning.

## Runbook

**Cut a release.** Bump `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` in `Config/Base.xcconfig` in a PR (CI fails
non-Dependabot PRs that don't) and merge
it. *iOS CI* on `main` publishes tag `v<marketing>-BUILD_<N>` once build and tests pass (Dependabot merges are
not tagged). A manual *iOS CI* run with `publish_release_tag: true` can also publish one; CI never starts a
release. Then start **Actions → *iOS Release* → Run workflow**, with **Use workflow from → Tags →** that tag —
the release refuses to run on a branch or on a tag that doesn't match the code. Dev builds automatically; Test and
Prod build after approvals A and C. Each uploads build `N` to its internal group.

**Promote to external TestFlight.** Actions → *iOS Promote* → Run workflow with `app` (`test`/`prod`),
`release_tag` and `target: external`. After approval B/D the job re-packages the archive from the release run
with the Environment's URL as build `N.1`, verifies it and uploads it to the external group(s). Allow time for
Beta App Review. Must happen within **90 days** of the build (archive retention = TestFlight expiry).

**Submit to the App Store (Prod only).** Run *iOS Promote* with `app: prod`, `release_tag`, `target: appstore`.
After approval E, the same `N.1` upload is submitted for review with phased release.

**How a tester confirms their backend.** The app logs its backend URL, version, build and commit at every launch
(shareable via the in-app diagnostics log). Build `N` = internal backend, `N.1` = external backend.

**Planned: GitHub Releases for Prod (not yet implemented).** When the Prod jobs land, each successful Prod
TestFlight upload will also create a GitHub Release: build `N` as *UAT* (pre-release, existing tag) and build `N.1`
as *Prod candidate* (pre-release, new tag `v<marketing>-BUILD_<N>.1`), with the `N.1` release becoming the full
*Latest* release on App Store submission. Details: ADR-0015, "Planned follow-up".

## Revisit when the mapping is confirmed

Re-check and update, then remove the PROVISIONAL banner:

- The mapping table above (any change of app ↔ channel ↔ backend).
- The `MMO_API_BASE_URL` value in each Environment, and that each is HTTPS with a trusted certificate.
- Required reviewers A–E and whether any stage should be ungated or merged.
- Whether Perf-Test needs a separate external group from release testing.
- The server-side acceptance rules each backend applies (optional App Attest — ADR-0015).
- ADR-0015's context table.
