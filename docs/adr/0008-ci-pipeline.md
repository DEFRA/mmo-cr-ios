# ADR 0008 — Continuous integration (PR validation) pipeline

- Status: Accepted
- Date: 2026-08
- Deciders: iOS engineering / DevOps
- Context tags: ci-cd, github-actions, fastlane, sonarcloud, swiftlint, native-iOS

## Context

The repository had no automated CI. Per the
[CI/CD standards](../../.github/instructions/ci-cd.instructions.md) and the working framework in
[copilot-instructions.md](../../.github/copilot-instructions.md), the app needs a pull-request
validation pipeline that lints, builds, tests with coverage, and feeds the SonarCloud quality gate —
running in the open in the DEFRA org, on GitHub-hosted macOS runners, with Fastlane as the Apple
toolkit.

This ADR covers **only the CI (PR validation) pipeline**. The release pipeline (signing, TestFlight /
App Store, gated GitHub Environments, versioning) and the GitHub-native security setup (CodeQL,
Dependabot) are separate future changes with their own ADRs, as is the gating configuration-strategy /
bundle-ID reconciliation.

## Decision

### 1. GitHub Actions workflow `.github/workflows/ios-ci.yml`

- Triggers on `pull_request` to `main` and `push` to `main`.
- `runs-on: macos-26`; least-privilege `permissions: contents: read`; a `concurrency` group cancels
  superseded PR runs (never other refs).
- Steps: **checkout** (full history for Sonar) → **select Xcode** (script, no third-party action) →
  **Ruby/Bundler** → **SPM cache** → **SwiftLint** → **Build** (plain `xcodebuild build`, catches
  compile errors independently of the test run) → **`bundle exec fastlane test`** (unit tests +
  coverage) → **convert coverage** → **SonarQube Cloud scan**.
- **POC deviation — remaining Actions pinned to version tags, not full commit SHAs.** The DEFRA CI/CD
  standard requires every third-party Action pinned to a full commit SHA (a supply-chain control: tags
  are mutable and can be repointed, e.g. the March 2025 `tj-actions/changed-files` compromise). For this
  proof-of-concept the workflow instead pins semantic version tags (e.g. `actions/checkout@v5.1.0`) for
  readability while the pipeline is being stood up. **This must be reverted to full-SHA pinning (with a
  version comment, updated by Dependabot) before this workflow is relied on for real branch-protection
  gating or release engineering**, or else raised as a formal governance exception with the Delivery
  Architecture team (`delivery.architecture@defra.gov.uk`).

### 2. Tests run through a minimal Fastlane `test` lane

`Gemfile` (Bundler) pins Fastlane; the `test` lane runs `run_tests` for the `record-catch` scheme with
code coverage and a result bundle. This keeps one automation model that the later release pipeline
reuses. `Appfile` carries only the bundle identifier; no App Store Connect credentials live in the repo.
`ruby/setup-ruby` (with `bundler-cache: true`) generates the lockfile on the runner when one is not
committed; a `Gemfile.lock` should be generated locally (`bundle install`) and committed to fully pin
the Fastlane dependency tree.

### 3. Unit tests now; UI tests deferred

Only the `record-catchTests` target runs in PR CI (`skip_testing: [record-catchUITests]`). XCUITests are
slower and flakier and will be added to CI in a follow-up once stabilised.

### 4. SwiftLint as the lint gate, conservative to start

A starter `.swiftlint.yml` is adopted. Rules are intentionally lenient at first so the gate is useful
without blocking on a backlog of pre-existing nits; strictness is ratcheted up over time. SwiftLint is
used from the runner (installed via Homebrew if not preinstalled).

### 5. SonarCloud (SonarQube Cloud) — wired now, inert until provisioned

`sonar-project.properties` holds the org/project keys and points coverage at `sonar-coverage.xml`
(generated from the Xcode `.xcresult` by `scripts/xccov-to-sonarqube-generic.sh`). The scan uses
`SonarSource/sonarqube-scan-action` and `sonar.qualitygate.wait=true` to fail CI on a failing gate.
Because the DEFRA SonarCloud project and `SONAR_TOKEN` are **not yet created**, the scan step is guarded
with `if: env.SONAR_TOKEN != ''` and is skipped (not failed) until the secret exists — so PRs stay green.

### 6. Xcode selection — inline script, not a third-party action

Rather than `maxim-lobanov/setup-xcode`, the workflow selects Xcode directly with a short `run:` script:
it globs `/Applications/Xcode_26*.app` (the paths GitHub documents for its `macos-26` image, which ships
multiple 26.x patches side by side, e.g. `Xcode_26.0.1.app` … `Xcode_26.6.app`), picks the highest via
`sort -V`, and runs `xcode-select -s "$XCODE_APP/Contents/Developer"`. This removes a third-party
dependency entirely (a stricter posture than SHA-pinning it) at the cost of a few lines of shell to
maintain. Only the major version (`26`) is targeted, so the script automatically tracks the latest
installed 26.x patch as the image is refreshed.

**Runner and Xcode major re-pinned to the latest GA (2026-08-25): `macos-26` / Xcode 26.x, simulator
device `iPhone 17`.** The pipeline initially pinned `macos-15` / Xcode 16.x to match the (lower) SDK the
project happened to need at the time, but neither the runner nor the Xcode major is derived from any
app-code setting — `project.pbxproj` has no enforced Xcode pin (only advisory `LastUpgradeCheck` /
`LastSwiftUpdateCheck` metadata) and no `.xcode-version` file exists. The re-pin is **CI/tooling only**:
it does **not** change `IPHONEOS_DEPLOYMENT_TARGET` (still 18.0/18.6), so the app's real minimum
supported iOS version for end users is unaffected — Xcode 26 still builds against that deployment
target. As before, this is a **deliberate, explicit pin** (`macos-26`, not the floating `macos-latest`
alias) so upgrades remain a reviewed, visible change rather than something that happens silently under
the workflow.

## Consequences

- PRs get fast, reproducible lint/build/test feedback with coverage.
- **Manual follow-up to activate SonarCloud:** create the project in the DEFRA org, disable *Automatic
  Analysis*, add the `SONAR_TOKEN` secret, then make the SonarCloud check required on `main`.
- **Follow-up required: re-pin Actions to full commit SHAs.** The version-tag pinning above is a
  known, deliberate, time-boxed POC deviation from the DEFRA supply-chain standard, not a
  permanent decision — track it to closure before this pipeline gates real merges/releases.
- The Xcode major-only pin trades exact-patch reproducibility for resilience to image refreshes.
- SwiftLint's first run may surface violations to fix or explicitly silence.
- The runner/Xcode/simulator pins will need periodic, deliberate bumps as GitHub deprecates older GA
  images (currently supports the latest 2 GA images) — a visible maintenance task, not a silent one.
- Out of scope here and tracked separately: release pipeline + signing, gated Environments/approvals,
  versioning model, CodeQL + Dependabot, and the configuration-strategy / bundle-ID ADRs.
