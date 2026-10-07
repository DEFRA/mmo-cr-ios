# ADR 0015 — Compile once, configure at promotion

- Status: Accepted (subject to spike S1 — see Validation); amended 2026-10 (see Amendments)
- Date: 2026-09
- Deciders: iOS engineering / DevOps
- Context tags: ci-cd, release, testflight, promotion, fastlane, security
- Related: [ADR-0011](0011-release-pipeline.md) (amended), [ADR-0014](0014-build-time-app-identity-configuration.md)

## Context

Five backends are served by three App Store Connect apps:

| App | Internal TestFlight | External TestFlight | App Store |
|---|---|---|---|
| Dev | Dev | Dev (the same build) | — |
| Test | Test | Perf-Test | — |
| Prod | Ext-Test (UAT) | Prod (sanity) | Prod |

A tester is in the internal **or** the external group of an app, never both. For Test and Prod the only
difference between the internal and external build is the backend URL, and we must not recompile to change it.
Dev uses one backend for both groups, so it has nothing to promote.

The device cannot tell an internal TestFlight install from an external one (StoreKit exposes only
App Store / TestFlight / Xcode). A single upload serving both backends therefore needs an external signal at
runtime.

## Options considered

**A. Build once + runtime promotion record** — one upload per app; the app fetches a signed "build N was
promoted" record (e.g. a GitHub Release asset) on first launch, plus an App Store lock.
Rejected: adds a third-party runtime dependency for TestFlight installs (offline first launch or a blocked /
unavailable `github.com` blocks testers), a new failure point and security surface (tester IPs to a third party,
a signing key to manage), and ships the Ext-Test URL inside the public App Store binary.

**B′. Compile once, configure at promotion** — chosen.

**Rebuild per stage** — rejected: recompiles, so the released code is only as equivalent as the toolchain.

## Decision

1. **Build** (`ios-release.yml`, one run per app): compile once, write the stage's `MMOCRAppConfig` (ADR-0014 §2),
   build number `N`, upload to **internal** TestFlight. Keep the `.xcarchive` as an **encrypted** artifact of the
   run. Record the executable's Mach-O UUID. Dev also assigns this same build to its external groups.
2. **Promote** (Test and Prod: a later, gated job in the **same** `ios-release.yml` run): take that same archive,
   replace `MMOCRAppConfig` with the external stage's values and set `CFBundleVersion` to `N.1`, export and re-sign,
   upload, assign to the **external** group. **No compiler runs.**
3. **App Store** (Prod only, the last job of the Prod run): submit the **same `N.1` upload** the sanity testers
   used — true build-once.

Each GitHub Environment holds one configuration set (`CR_APP_CFG_*` variables), so the Environment a job runs in
determines the backend:
`dev` → Dev (internal and external groups) · `test` → Test · `test-external` → Perf-Test · `prod` → Ext-Test ·
`prod-external` → Prod.

### Terminology (use consistently)

- **Compile once** — the compiled program is produced once and reused; the package around it (settings,
  signature, build number) may differ. Applies to internal → external.
- **Build once** — the exact same upload moves on. Applies to external → App Store.
- Say "no recompile", not "no rebuild", for promotion.

### Promotion safeguards (the job fails if any check fails)

1. Archive bundle ID and build number match the requested app and tag, and the packaged `MMOCRAppConfig` equals
   the validated values exactly.
2. The executable's Mach-O UUID equals the UUID recorded at build time — proof of identical compiled code
   (re-signing rewrites the embedded signature, so a file hash is not a valid comparison).
3. `codesign --verify --deep --strict` passes on the exported app.
4. No internal-only host name appears anywhere in the external package: every host from the archive's `url`
   values that the external configuration does not also use — so the public App Store package provably contains no
   Ext-Test URL.
5. Idempotent re-run: if `N.1` is already uploaded, skip the upload and continue to distribution.

### Run model: one `ios-release.yml` run per app

`ios-release.yml` is the only release workflow. It is started manually on the release tag with an `app` input, and
each run holds that app's build and its promotions, so the archive never leaves the run:

| Run (`app`) | Jobs (Environment, gate) |
|---|---|
| `dev` | `dev-build` (`dev`, none) |
| `test` | `test-build` (`test`, A) → `test-promote-external` (`test-external`, B) |
| `prod` | `prod-build` (`prod`, C) → `prod-promote-external` (`prod-external`, D) → `prod-appstore-submit` (`prod-appstore`, E) |

A GitHub workflow run is cancelled after **35 days including approval waits**, and a single approval can wait at
most **30 days**. These limits are **accepted**: sprint plus release testing fits in the Test run, and UAT plus prod
sanity plus App Store submission fits in the Prod run. The Prod run is started only after release testing has signed
off the candidate, so Approval C never waits on another app's testing. The concurrency group includes the app, so
runs of one tag for different apps run side by side.

## Consequences

- No runtime lookup: the app reads one URL from its own `Info.plist`, works offline, and needs no promotion
  logic. The App Store package contains only the Prod URL.
- Internal and external builds of an app have different build numbers (`N` / `N.1`) — traceable to the same tag
  and commit.
- External promotion is **repackage + upload + Beta App Review**, not an App Store Connect metadata-only action
  — a deliberate change to the previous standard (updated in `ci-cd.instructions.md`).
- Each app's promotions must happen within its run: 35 days from the start of the run, and 30 days per approval.
  If a run is cancelled by the limit, its uploads stay in TestFlight but cannot be promoted; bump the version and
  release again. The archive artifact's 90-day retention and the TestFlight build lifetime are both longer.
- The archive artifact is encrypted with `ARCHIVE_ENCRYPTION_KEY` (shared by each build Environment and its
  promotion Environment) because public-repository artifacts are downloadable by any signed-in GitHub user.
- Server-side App Attest on non-prod backends is optional defence in depth, not a dependency.

## Validation

**Validated on the Dev app first** (`mmo.catchrecordingdev.ios` only — Test and Prod untouched):
`ios-release.yml` job `dev-build` compiles once with the `dev` Environment's URL and uploads build `N` to internal
TestFlight; job `dev-promote-external` (Environment `dev_external`, required reviewer) re-packages the same
archive with `dev_external`'s URL as `N.1`, runs the UUID / `codesign` / host-scan checks and uploads it to the
Dev app's external group. This is a deliberate, approved release of the Dev app, and it is also the first proof
that App Store Connect accepts an edited-archive export. If it is rejected, the fallback is editing the exported
`.ipa` and re-signing with Fastlane `resign`. Record the outcome here.

The Dev demo already uses the in-run promotion that the Test and Prod runs will use. In the target, Dev sends one
build on the Dev backend to both its groups, and the `dev_external` demo is retired.

## Planned follow-up: a GitHub Release per Prod TestFlight stage

Not implemented yet — to be added with the Prod jobs. CI only creates tags; the release pipeline will record each
Prod TestFlight distribution as a GitHub Release, created as the job's last step **after** the upload succeeds:

| Stage | Build | Tag | Release | Marked as |
|---|---|---|---|---|
| Prod → internal TestFlight (UAT) | `N` | `v<marketing>-BUILD_<N>` (created by CI) | `v<marketing> (<N>) — UAT` | Pre-release |
| Prod → external TestFlight (prod candidate) | `N.1` | `v<marketing>-BUILD_<N>.1` on the same commit (created by the release step) | `v<marketing> (<N>.1) — Prod candidate` | Pre-release |
| App Store submission | same `N.1` | — | the `N.1` release | Full release, marked **Latest** |

- Notes: changes since the previous release tag plus app, version, build, channel, commit and workflow-run link.
  No backend URLs and no IPA attached (public repository).
- Idempotent on re-run (skip if the release exists); only these jobs get `contents: write`.
- `validate-release-tag.sh` already rejects `.1` tags, so a promotion tag can never be released again.
- If the `v*` tag ruleset restricts tag creation, the release workflow needs a bypass to create the `.1` tag.

## Amendments

- **2026-10 — promotions inside `ios-release.yml`.** The separately dispatched `ios-promote.yml` is dropped. Each
  app has its own `ios-release.yml` run (`app` input) holding its build, its promotion and, for Prod, the App Store
  submission; GitHub's 35-day run and 30-day approval limits are accepted (see *Run model*). Cross-run archive
  download is no longer needed.
- **2026-10 — Dev uses one backend.** Dev's internal and external groups both use the Dev backend and the same
  build `N`, ungated; `dev_external` is a proof of concept only. Assigning external groups needs an App Manager key
  in the ungated `dev` Environment, an open exception (DevOps design deviation D14).

## Sources

- GitHub Actions limits (35-day run, 30-day approval): https://docs.github.com/en/actions/reference/limits
- GitHub immutable releases: https://docs.github.com/en/code-security/supply-chain-security/understanding-your-software-supply-chain/immutable-releases
- `actions/download-artifact` (in-run download): https://github.com/actions/download-artifact
- StoreKit `AppTransaction.environment` / TestFlight sandbox: https://developer.apple.com/documentation/storekit/testing-in-app-purchases-with-sandbox
- Fastlane `build_app` (`skip_build_archive`, `archive_path`) and `resign`: https://docs.fastlane.tools/actions/build_app/ · https://docs.fastlane.tools/actions/resign/
