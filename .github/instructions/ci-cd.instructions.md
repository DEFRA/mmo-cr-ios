---
description: "CI/CD and release-engineering standards for the MMO Catch Recording iOS app: GitHub Actions + Fastlane on GitHub-hosted macOS runners, trunk-based development with tag-driven releases, SemVer + build numbering, gated GitHub Environments, code signing, secrets management, SonarCloud, and the GitHub-native security features (CodeQL, Dependabot, secret scanning). Use when creating or reviewing pipelines, workflows, Fastlane config, signing, versioning or release management."
applyTo: ".github/workflows/**, .github/dependabot.yml, fastlane/**, **/*.xcconfig, **/Gemfile, **/Gemfile.lock, **/Matchfile, **/Appfile, **/Fastfile, **/exportOptions*.plist"
---

# CI/CD & release-engineering standards (iOS)

These standards govern continuous integration, delivery and release engineering for the **MMO Catch
Recording native iOS app**. This is an **iOS-only** repository — Android is delivered from a separate
repository, so **never add Android tooling, tracks, Gradle, Play Console or cross-platform build matrices
here**.

Precedence follows [copilot-instructions.md](../copilot-instructions.md): **DEFRA > GDS > Apple >
community**. The mandatory DEFRA constraints (offline-first, encryption in transit, protect data at rest,
error logging, code-in-the-open, never commit secrets, WCAG 2.2 AA, Secure by Design) all still apply to
release engineering. Any deviation from a DEFRA standard must be raised as a governance exception
(Delivery Architecture: `delivery.architecture@defra.gov.uk`).

## Tooling (fixed decisions)

- **CI orchestrator:** **GitHub Actions** is the single authoritative CI/CD orchestration and audit
  platform. All PR validation, main-branch validation and manually dispatched releases run here. GitHub Actions
  decides **when** a job runs and **with what permissions**; Fastlane does the Apple-specific work.
- **Deployment engine:** **Fastlane** — chosen to keep one uniform automation model across the iOS and
  (separately-hosted) Android apps. It is the Apple release toolkit, **not** a second orchestrator. Build,
  sign, version, and upload to TestFlight / App Store Connect are all driven by Fastlane lanes. Do **not**
  introduce a second deployment mechanism.
- **Build infrastructure:** **GitHub-hosted macOS runners** (e.g. `macos-15`). Do not assume self-hosted
  Macs. Pin the runner image and the Xcode version explicitly so builds are reproducible.
- **Quality/coverage:** **SonarCloud** (DEFRA organisation) is the source of truth for coverage and the
  quality gate.
- **Dependencies:** **Swift Package Manager** for app dependencies; **Bundler** (`Gemfile`) to pin
  Fastlane and its plugins. No CocoaPods/Carthage.

### Alternative: Xcode Cloud (ADR-gated, never in parallel)

**Xcode Cloud** is the only approved alternative orchestrator, and only if the organisation decides Apple
should own the build and signing trust boundary (e.g. exporting a distribution private key into
GitHub-controlled systems is prohibited, or Apple-managed signing/certificate rotation is mandatory).
If adopted it **replaces** the relevant GitHub Actions release responsibilities — it must **never run
alongside** them (two orchestrators mean split ownership, duplicated build logic and scattered audit
evidence). Xcode Cloud may only be adopted through an approved **ADR** that addresses governance, security
controls, audit evidence, cost, and integration with the GitHub quality gates.

## Branching & release model — trunk-based, tag-driven (no release branches)

This is a **small team practising trunk-based development**. The model is deliberately minimal:

- **`main` is the trunk** and is always releasable. Protect it: require PRs, green CI and review before
  merge; no direct pushes.
- **Short-lived feature branches** (`feature/*`) merge back into `main` via PR, then are deleted.
- **Every merge to `main` publishes a release tag — except Dependabot merges**, which carry no version bump and
  ship with the next bumped release. Once build and tests pass on `main`, *iOS CI* pushes the tag. A manual *iOS
  CI* run with `publish_release_tag: true` (default `false`) also publishes one. **CI only tags; it never starts a
  release.** Tag format:
  **`vMAJOR.MINOR.PATCH-BUILD_BUILDNUMBER`** (e.g. `v2.0.0-BUILD_9`), derived from `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `Config/Base.xcconfig` (ADR-0014).
- **Releases have one entry point: manual `workflow_dispatch` of *iOS Release* on a release tag** ("Use workflow
  from" → the tag). There is no tag-push trigger and no version input: the release fails unless it runs on a tag
  and that tag matches the version in the code at that tag.
- **Protect release tags** with a repository ruleset on `v*`: block updates and deletions (and force pushes). If
  tag *creation* is also restricted, *iOS CI* must be allowed to bypass it or merges can no longer be tagged.
- **POC exception (time-boxed):** tags — and therefore releases — may be published from non-`main` branches via a
  manual *iOS CI* run. **Hardening after the POC:** tag and release from `main` only (guard the tag job on
  `refs/heads/main` and require the Environments' deployment rule to match) — tracked in ADR-0011 "Post-POC
  hardening" together with full-SHA Action pinning.
- **Hotfixes** are a normal fix on `main` with incremented version/build numbers merged via PR, which publishes
  the tag as above. Because
  the trunk is always releasable, there is no separate hotfix branch to maintain.
- **Release branches are NOT used and MUST NOT be introduced** for this app. They only earn their keep
  when a release must be hardened/stabilised while `main` keeps moving, or when several past versions are
  supported in parallel — neither applies to a single-team, single-live-version app. Tag-driven releases
  give a clean, auditable release point without the merge overhead. If a future need for release branches
  is identified, raise it as an ADR + governance discussion first; do not add them ad hoc.

## Versioning

- **Single source of truth in code** ([ADR-0011](../../docs/adr/0011-release-pipeline.md) §3a, amended by
  [ADR-0014](../../docs/adr/0014-build-time-app-identity-configuration.md)): `MARKETING_VERSION`
  (`CFBundleShortVersionString`) and `CURRENT_PROJECT_VERSION` (`CFBundleVersion`, build `N`) live in
  `Config/Base.xcconfig`. Developers bump them in a PR; merging to `main` publishes the tag
  `v<marketing>-BUILD_<N>`, and the release workflow validates the tag against the file.
- **External promotion build number is `N.1`** ([ADR-0015](../../docs/adr/0015-compile-once-configure-at-promotion.md)):
  the promoted package of build `N` is uploaded as `N.1` (a valid `CFBundleVersion` — up to three
  period-separated integers), keeping it unique within the App Store Connect app and traceable to the tag.
- **Do not query App Store Connect for the build number** — a network lookup adds a race between concurrent
  releases and pulls release credentials into a step that does not need them.
- **Every non-Dependabot PR must bump the version.** *iOS CI* fails the PR if its release tag already exists or its
  build is not higher than the target branch's; Dependabot PRs are exempt and ship with the next bump.
- **The one rule that must hold:** for a given marketing version each uploaded build number must be
  **unique and higher** than the previous upload for that version. Never reuse or hand-edit a released value.
- **Commit SHA is traceability, not the build number.** Embed the short Git SHA as read-only `Info.plist`
  metadata (`GitCommitSHA`). A SHA is hexadecimal and non-monotonic, so it can never be `CFBundleVersion`.

## Configuration strategy — compile once, configure at promotion (frozen)

**Frozen decision** ([ADR-0014](../../docs/adr/0014-build-time-app-identity-configuration.md),
[ADR-0015](../../docs/adr/0015-compile-once-configure-at-promotion.md)): the app ships as **three App Store
Connect apps** serving **five backends**. The app holds **exactly one backend URL** (`MMOAPIBaseURL` in
`Info.plist`) and has **no runtime environment selector** and no runtime lookup.

| App | Internal TestFlight | External TestFlight | App Store |
|---|---|---|---|
| Dev (`mmo.catchrecordingdev.ios`) | Dev | — | — |
| Test (`mmo.catchrecordingtest.ios`) | Test | Perf-Test | — |
| Prod (`mmo.catchrecording.ios`) | Ext-Test (UAT) | Prod (sanity) | Prod |

- **Identity at build time.** Bundle ID and display name come from `Config/<App>.xcconfig` via the app's
  scheme/configuration. The **backend URL is never in git**: it is a **GitHub Environment variable**
  (`MMO_API_BASE_URL`, one per Environment) injected by Fastlane as a command-line build setting.
- **Compile once, configure at promotion.** Each app is compiled **once** per release (build `N`, internal
  TestFlight). Promotion to external TestFlight re-uses that **same archive**: Fastlane swaps `MMOAPIBaseURL`
  to the external stage's URL, sets the build to `N.1`, re-signs and uploads. **No compiler runs.** The
  promotion job must prove it: identical Mach-O UUID, `codesign --verify --deep --strict`, and the internal
  backend's host absent from the external package.
- **Build once from external to App Store.** The Prod App Store submission is the **same `N.1` upload** the
  sanity testers used.
- **Vocabulary:** say **"no recompile" / "same compiled code"** for internal → external, and reserve
  **"build once"** for the same-upload external → App Store step.

## Application identity & bundle-ID model (frozen)

**Three application identities** — three App Store Connect apps, three TestFlight surfaces:

```
mmo.catchrecordingdev.ios     # Dev  — internal TestFlight
mmo.catchrecordingtest.ios    # Test — internal + external TestFlight (release testing / perf)
mmo.catchrecording.ios        # Prod — internal (UAT) + external (sanity) TestFlight + App Store
```

- Each app installs **side by side** on one device (distinct bundle IDs). Within one app, a tester is in the
  internal **or** the external group, never both.
- Only the **Prod** app is ever submitted to the App Store; **Dev** and **Test** are TestFlight-only app
  records.
- Each app has its **own** provisioning profile and entitlements (APNs, associated domains, keychain) and
  an **independent build-number namespace**; external TestFlight on each app triggers its own Apple Beta
  App Review and 90-day build-expiry clock.

## Release management (development → production)

The flow from a developer's change to a production App Store release:

```
short-lived feature branch  ──PR──▶  main (trunk, always releasable)
  │  PR CI: SwiftLint · build · unit/UI tests + coverage · SonarCloud PR analysis
  │  GitHub-native gates: CodeQL · Dependabot · secret scanning + push protection
  ▼
main CI: full tests + SonarCloud main analysis + release tag vX.Y.Z-BUILD_N (every non-Dependabot merge)
  ▼  (manual: iOS Release → Run workflow on the tag — the only way a release starts)
  ▼
ios-release.yml (manual dispatch on a tag) — compile each app ONCE, keep the encrypted .xcarchive (90 days)
  ├─ dev-build     [env: dev — no gate]     Dev app  N → internal TestFlight (Dev)
  ├─ test-build    [env: test — APPROVAL A] Test app N → internal TestFlight (Test)
  └─ prod-build    [env: prod — APPROVAL C] Prod app N → internal TestFlight (Ext-Test / UAT)
  ▼
ios-promote.yml (manual dispatch per promotion) — no recompile
  ├─ test-promote-external [env: test-external — APPROVAL B] same archive → URL Perf-Test, build N.1 → external
  ├─ prod-promote-external [env: prod-external — APPROVAL D] same archive → URL Prod, build N.1 → external (sanity)
  └─ prod-appstore-submit  [env: prod-appstore — APPROVAL E] SAME N.1 upload → App Store (phased release)
  ▼
monitor (App Store Connect metrics + crash reporting)  ──▶  hotfix = fix on main + higher patch tag
```

Promotion is a **separate workflow** because a GitHub workflow run is cancelled after **35 days including
approval waits** (a single approval may wait at most 30 days); testing between stages can exceed that.

### GitHub Environments & approval gates

Define **six** governed GitHub Environments. A GitHub Environment approval gates the **start of a job**, so
each distinct manual approval is its own job / environment. Each Environment (except `prod-appstore`) holds
exactly **one** backend URL as the variable `MMO_API_BASE_URL`, so the Environment determines the backend.

| Environment | Workflow · job | Backend URL | Approval |
|-------------|----------------|-------------|----------|
| `dev` | `ios-release` · `dev-build` | Dev | None (auto on tag) |
| `test` | `ios-release` · `test-build` | Test | **Required reviewer** (A); prevent self-approval |
| `prod` | `ios-release` · `prod-build` | Ext-Test | **Required reviewer** (C); prevent self-approval |
| `test-external` | `ios-promote` · `test-promote-external` | Perf-Test | **Required reviewer** (B) |
| `prod-external` | `ios-promote` · `prod-promote-external` | Prod | **Required reviewer** (D) |
| `prod-appstore` | `ios-promote` · `prod-appstore-submit` | — (submits `N.1` as-is) | **Required business/release reviewer** (E); prevent self-approval + admin bypass |

A seventh Environment, **`dev_external`** (`ios-release` · `dev-promote-external`, required reviewer), demonstrates
the gate and the no-recompile promotion on the **Dev** app only; it runs in the same workflow run as `dev-build`.

- Scope each stage's release secrets to its **own** Environment, not the repo, so they are only exposed
  after that stage's approval. Do not mix SonarCloud credentials with signing/release credentials.
- Restrict all six Environments' deployments to `main` and the `v*` tags. Keep workflow
  `permissions:` least-privilege even after environment approval.
- **Use phased release** for App Store production; monitor crash-free rate and key metrics before
  completing the roll-out. Keep the ability to pause the phased release.

### Distribution

- **TestFlight** for beta, across **two distinct gates**: the **internal** QA group first (fast
  release-candidate smoke test by App Store Connect team members — up to 100 internal testers), then an
  **external** UAT group (business users who do not need App Store Connect roles — up to 10,000 external
  testers, subject to TestFlight Beta App Review). Provide tester-friendly release notes ("what to test",
  "known limitations", environment details, feedback channel). TestFlight builds stay available for a
  limited window (currently up to 90 days).
- **App Store** for production: submit the **Prod app's `N.1` upload** (the one sanity-tested on external
  TestFlight) via `upload_to_app_store`, submitted for review then released in phases. Uploading a build,
  submitting a version for review, and releasing an approved version are **three separate actions** — model
  them separately in automation and runbooks.

## Security gates — native GitHub features vs CI workflow stages

Be precise about *where* each control lives. **Do not turn a native feature into a hand-rolled CI stage
unless a separate workflow is explicitly required.**

**GitHub-native (configured in repo Settings or a config file — not part of the Fastlane build/test/release
workflows):**

- **CodeQL (SAST).** CodeQL supports Swift. Two options:
  - **Default setup** — enabled in *Settings → Code security → Code scanning*; GitHub manages the run
    (uses `autobuild` for Swift on macOS runners). No hand-written workflow.
  - **Advanced setup** — a dedicated **`.github/workflows/codeql.yml`** workflow you maintain. Use this
    when you need control over the Swift build, the query suite, triggers or the runner. **This repo
    maintains CodeQL as its own separate advanced-setup workflow** (see the release-pipeline skill), so the
    Swift build step is explicit and reproducible. Keep it in its **own** workflow file, separate from the
    PR-CI and release workflows.
- **Dependabot.** Configured via **`.github/dependabot.yml`** (a native config file — *not* a GitHub
  Actions workflow). Maintain it as its **own separate file**, covering the `github-actions`, `swift` (SPM)
  and `bundler` ecosystems. Optionally pair it with a small auto-merge workflow for patch/minor security
  updates, but the update mechanism itself is `dependabot.yml`.
- **Secret scanning + push protection.** Enabled in *Settings → Code security*. Native — no workflow. If a
  secret is ever exposed, follow DEFRA's
  [credential exposure](https://defra.github.io/software-development-standards/processes/credential_exposure/)
  process immediately.

**CI workflow stages (GitHub Actions files you author):**

- **PR CI** (`.github/workflows/ios-ci.yml`) — SwiftLint, build, unit/UI tests with coverage, then the
  **SonarCloud** scan. Runs on pull requests and pushes to `main`.
- **Release** (`.github/workflows/ios-release.yml`) — manually dispatched on a release tag; compiles each app once behind the
  gated Environments above. **Promotion** (`.github/workflows/ios-promote.yml`) — manually dispatched;
  re-packages and promotes without recompiling.
- **CodeQL** (`.github/workflows/codeql.yml`) — the separate advanced-setup SAST workflow described above.

**MobSF binary (IPA) scanning** is **not required** for the baseline: SonarCloud + CodeQL + Dependabot +
secret scanning already give strong coverage for a small team. Treat MobSF as an **optional later maturity
step**; if adopted, run it against the signed IPA before the production gate.

## Code signing

- **Do not commit certificates, provisioning profiles, `.p12` files or private keys** to the repository.
- The signing approach is a decision to be **researched, recommended in the agent's plan and recorded as an
  ADR**. Three options, in order of preference:
  1. **Fastlane Match (recommended)** — an encrypted, centrally controlled signing store (private Git repo
     or approved object store) with **read-only** CI access (`match(readonly: true)`). Restrict write
     access to a small signing-administrator group; give release automation read-only access; separate the
     encrypted data from its decryption credential where practical; prohibit destructive Match operations
     from ordinary CI; assess all apps sharing the Apple Developer team before revoking a certificate.
  2. **Manual `.p12` + provisioning profile (fallback)** — base64-encoded certificate and profiles stored
     as protected Environment secrets, decoded and imported into a temporary keychain during the release
     job. Simpler footprint but manual renewal/rotation and higher mismatch risk. Base64 is encoding only
     — protection relies on GitHub secret storage and access policy.
  3. **Xcode Cloud managed signing (ADR alternative)** — Apple cloud-managed certificates, used only if
     organisational policy prohibits exportable distribution private keys in GitHub-controlled systems.
     This changes the delivery architecture and must be approved via ADR, not bolted on beside the GitHub
     Actions release process.
- Whichever is chosen:
  - Use **App Store Connect API key** authentication (`app_store_connect_api_key`) for uploads — not an
    Apple ID + password. Signing (certificate + key + profile) and App Store Connect API authentication are
    **separate concerns**; the API key does not replace signing material.
  - In CI, materialise signing assets into a **temporary keychain** deleted at the end of the job.
  - Use **least-privilege** App Store Connect roles; rotate the API key periodically; monitor certificate
    and profile expiry; document rotation, revocation and recovery procedures.

## Secrets management

- **Never commit secrets.** Store all release secrets as **GitHub Actions encrypted secrets scoped to the
  gated Environments** (`dev` / `test` / `test-external` / `prod` / `prod-external` / `prod-appstore`) —
  each stage exposing only the credentials it needs (per-app signing/upload, and the external-distribution
  and App Store submission credentials, are kept separate).
- Typical secrets: `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_CONTENT` (App Store Connect API key),
  `APPLE_TEAM_ID`, `MATCH_PASSWORD`, `MATCH_DEPLOY_KEY`, and `ARCHIVE_ENCRYPTION_KEY` (shared by a build
  Environment and its promotion Environment); plus `SONAR_TOKEN`.
- **Backend URLs are Environment variables, not secrets** (`MMO_API_BASE_URL`, one per Environment) — not
  sensitive, auditable, and never committed to git.
- Non-sensitive build configuration (bundle ID, display name, versions) belongs in **`.xcconfig`** files
  committed to the repo. Document every config key in the config file and the README.
- **Never print secrets to logs.** Do not echo signing identities, profiles, API keys or keychain
  contents. Rely on GitHub's masking and keep `set -x` away from secret-bearing steps.
- **Pin every third-party GitHub Action to a full commit SHA** (a DEFRA supply-chain requirement) and set
  least-privilege `permissions:` on every workflow. Enable Dependabot, CodeQL, secret scanning, push
  protection and dependency review; gate workflow/release-tooling changes behind CODEOWNERS or equivalent
  protected review.

## Reliability & reproducibility

- Pin the runner image, Xcode version, Ruby version and Fastlane (via `Gemfile.lock`). Cache SPM and
  Bundler dependencies (only where cache keys prevent unsafe cross-context restoration).
- Use `concurrency:` groups to cancel superseded PR runs but **never** cancel an in-flight release run.
- Every release must be traceable end to end: **release tag → commit SHA → workflow run → marketing
  version → build number (`N` / `N.1`) → Mach-O UUID → App Store Connect build → TestFlight groups &
  sign-off → App Store version & release status**.

## Real-device testing & data residency (optional maturity step)

Simulator suites in CI cover broad automation; a cloud real-device service (e.g. **BrowserStack App
Automate**) may supplement — not replace — simulators and human UAT for hardware, OS-version, network,
offline and compatibility scenarios. It is **subject to procurement and security approval**. Because a
real cloud device processes app data **in memory** even though nothing is persisted there and the backend
stays **UK-hosted**, the **cloud devices used must be UK-located** to satisfy data-residency requirements.
Record adoption and the residency constraint as an **ADR**.

## Architecture decision records (create/update before privileged automation)

Record at least these as ADRs under `docs/adr/`:

1. GitHub Actions + Fastlane as the iOS delivery architecture (and the native-app exception).
2. **Build-time app identity configuration** — three apps via `.xcconfig`, backend URL injected from CI
   ([ADR-0014](../../docs/adr/0014-build-time-app-identity-configuration.md)).
3. Code-signing strategy and signing-asset custody (three bundle IDs managed by Match).
4. **Three-application bundle-ID and five-backend environment model** (`dev` / `test` / `prod` as separate
   App Store Connect apps).
5. **Release topology** — manually dispatched build workflow (on a release tag) + manually dispatched promotion workflow, six gated
   Environments.
6. **Compile once, configure at promotion** — no recompile internal → external; build once external → App
   Store ([ADR-0015](../../docs/adr/0015-compile-once-configure-at-promotion.md)).
7. Internal & external TestFlight distribution model (per-app internal + external groups).
8. Cloud real-device testing platform and UK data residency, if adopted.
9. Production approval and phased-release policy.

## Definition of Done (pipeline changes)

- [ ] Workflow YAML is valid, least-privilege (`permissions:`), and pins Actions (full commit SHA) + tool versions
- [ ] Secrets are Environment-scoped per stage, never committed, never logged
- [ ] Trunk-based/tag-driven model preserved — no release branch introduced
- [ ] Versions come from `Config/Base.xcconfig` and the tag; external promotions use `N.1` (no App Store Connect query); `GitCommitSHA` embedded as traceability metadata
- [ ] The gated Environments (`test`, `test-external`, `prod`, `prod-external`, `prod-appstore`) remain gated by manual approval (`dev` is ungated), with self-approval prevented where supported
- [ ] Each app compiled once per release; promotion re-uses the same archive and proves it (Mach-O UUID match, `codesign` verify, internal backend host absent); App Store submits the same `N.1` upload
- [ ] Backend URLs come only from GitHub Environment variables — never committed
- [ ] SonarCloud quality gate wired and passing; coverage reported
- [ ] CodeQL and Dependabot maintained as their own separate files
- [ ] Signing uses App Store Connect API key + temporary keychain; assets never committed
- [ ] Configuration-strategy, bundle-ID and signing decisions recorded as ADRs; README updated for any new pipeline, secret, environment or signing decision
- [ ] No Android tooling added to this iOS-only repo
