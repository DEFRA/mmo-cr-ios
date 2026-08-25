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
  platform. All PR validation, main-branch validation and tag-triggered releases run here. GitHub Actions
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
- **Releases are cut from a Git tag on `main`**, never from a long-lived branch. Tag format:
  **`ios-vMAJOR.MINOR.PATCH`** (e.g. `ios-v1.4.0`). Pushing a matching tag triggers the release workflow.
- **Hotfixes** are a normal fix on `main` plus a **new higher patch tag** (e.g. `ios-v1.4.1`). Because
  the trunk is always releasable, there is no separate hotfix branch to maintain.
- **Release branches are NOT used and MUST NOT be introduced** for this app. They only earn their keep
  when a release must be hardened/stabilised while `main` keeps moving, or when several past versions are
  supported in parallel — neither applies to a single-team, single-live-version app. Tag-driven releases
  give a clean, auditable release point without the merge overhead. If a future need for release branches
  is identified, raise it as an ADR + governance discussion first; do not add them ad hoc.

## Versioning

- **Marketing version** (`CFBundleShortVersionString`, e.g. `1.4.0`) is derived from the release **tag**
  (`ios-v1.4.0` → `1.4.0`). It is the single human-facing SemVer.
- **Build number** (`CFBundleVersion`) is derived **deterministically** from the **release workflow's**
  `GITHUB_RUN_NUMBER` (which increments by one on every release run). **Do not query App Store Connect for
  the latest build number** — a network lookup adds a race condition between concurrent releases and pulls
  release credentials into a step that does not need them. The CI run counter avoids all three and keeps
  versioning fully derivable from the tagged commit.
  - **The one rule that must hold:** for a given marketing version each uploaded build number must be
    **unique and higher** than the previous upload for that version. The run number satisfies this for
    normal serialised releases. Global cross-version monotonicity is **deliberately not enforced**; if the
    release workflow is ever reset/replaced such that the run number could regress, apply a documented
    one-off offset — do **not** reintroduce an App Store Connect lookup.
  - **Commit SHA is traceability, not the build number.** Embed the short Git SHA (and the tag) as
    read-only `Info.plist` metadata (e.g. a `GitCommitSHA` key) for traceability only. A SHA is
    hexadecimal and non-monotonic, so it can never serve as `CFBundleVersion` (which must be
    period-separated integers).
- Fastlane sets both at build time (`increment_build_number` / `increment_version_number`); do not
  hard-code version numbers in the Xcode project for release builds. **Never** edit the build number by
  hand and never reuse a value for a marketing version.

## Configuration strategy & build-once-and-promote (ADR-gated — resolve first)

The configuration strategy is the **highest-priority open decision** and the **whole build/release model
depends on it**. Settle it as an **ADR before the release pipeline is finalised**.

- **Option A — runtime configuration (recommended default): build once, promote the binary.** The signed
  binary contains no hard-coded environment; it resolves its environment at launch from a governed,
  tamper-resistant source (a compiled-in default plus securely delivered configuration, or environment
  selection tied to the signed distribution channel). This preserves **build-once-and-promote**: the exact
  App Store Connect build tested in UAT is the build released to production. A production user must **never**
  be able to point the app at arbitrary services — do not expose an unrestricted endpoint selector in the
  production app, and never edit a signed artifact to change configuration.
- **Option B — build-time configuration: rebuild per environment.** Each environment is compiled with its
  own settings via `.xcconfig` and build configurations, producing a **distinct binary per environment**.
  Build-once-and-promote does **not** apply; promotion is instead of a **fixed, tested source commit** —
  the production build is a separate archive from that same commit, evidenced by equivalence (same commit
  SHA, pinned toolchain, locked dependencies) rather than an identical-binary guarantee.

**Immutable promotion (under Option A).** Build the release candidate **once**, then promote that exact
App Store Connect build through internal QA → external UAT → App Store, with **no rebuild** between UAT
approval and production release (a rebuild can silently change compiler output, resolved dependencies,
embedded configuration, timestamps or signing details). Because a bundle identifier cannot change after
upload, the candidate is signed with the **production** bundle ID from its first upload, so internal QA and
external UAT exercise the production-identity build.

**Current repo state (must be reconciled):** the app has **no configuration mechanism yet**
(`AppEnvironment` is an empty placeholder, backend providers are protocol-shaped stubs per ADR-0004, there
are no `.xcconfig` files and no API base URL), and the Xcode project ships a single hard-coded bundle
identifier (`mmo.catchrecordingdev.ios`) with hard-coded version/build values that differ from the
`uk.gov.defra.*` identities and CI-derived versioning proposed below. Configuration, bundle-ID and
versioning must be designed **together**, not retrofitted.

## Application identity & bundle-ID model (ADR-gated)

Default to **two application identities**, adding a third only if a real capability/isolation requirement
demands it:

```
uk.gov.defra.catchrecording.nonprod   # development + automated system test
uk.gov.defra.catchrecording           # production candidate + production
```

- Development and automated system testing use the **non-production** app + non-production backend.
- UAT uses the **actual production** application identity and release candidate through TestFlight.
- Production selects the same UAT-approved App Store Connect build for App Store release.

Use a **separate bundle ID per environment** (`.test` / `.uat` / prod) only when installs must coexist on
one device, or when push notifications, associated domains, App Groups or auth redirects need strict
per-environment isolation — accept the extra App IDs, profiles and drift risk. Record the chosen model as
an **ADR**, and reconcile it with the current single hard-coded bundle identifier.

## Release management (development → production)

The flow from a developer's change to a production App Store release:

```
short-lived feature branch  ──PR──▶  main (trunk, always releasable)
  │  PR CI: SwiftLint · build · unit/UI tests + coverage · SonarCloud PR analysis
  │  GitHub-native gates: CodeQL · Dependabot · secret scanning + push protection
  ▼
main CI: full tests + SonarCloud main analysis
  ▼
tag  ios-vX.Y.Z  ──▶  release workflow (Fastlane)
  ├─ build_release  (build + sign ONCE; build number = release GITHUB_RUN_NUMBER; GitCommitSHA metadata)
  ├─ [Environment: mobile-internal-beta — MANUAL APPROVAL]  upload_to_testflight → internal QA group
  │      └─ internal QA smoke / exploratory sign-off
  ├─ [Environment: mobile-uat — MANUAL APPROVAL]  distribute the SAME build → external UAT group
  │      └─ business UAT sign-off (no rebuild)
  └─ [Environment: mobile-production — MANUAL APPROVAL]  select the SAME build → App Store (phased release)
  ▼
monitor (App Store Connect metrics + crash reporting)  ──▶  hotfix = fix on main + higher patch tag
```

### GitHub Environments & approval gates

Define **three** governed GitHub Environments — one gate at each point of distribution — **all gated by
required manual reviewers** for this app. Name them for the delivery **stage**, not for physical
infrastructure. A stage may only be reached once the preceding gate is approved, preserving the
build-once-and-promote model.

| Environment | Purpose | Trigger | Approval |
|-------------|---------|---------|----------|
| `mobile-internal-beta` | Build → sign → upload the release candidate to the **internal** TestFlight QA group; exposes only internal-distribution credentials | Release tag or manual `workflow_dispatch` | **Required reviewer(s)**; prevent self-approval where supported |
| `mobile-uat` | Distribute the **same** build to the **external** TestFlight UAT group; exposes only UAT-distribution credentials | After internal QA sign-off | **Required reviewer(s)**; prevent self-approval where supported |
| `mobile-production` | Select the **same** build for App Store submission / production release (**phased release**); exposes production credentials | After UAT sign-off | **Required business/release reviewer(s)**; prevent self-approval and admin bypass where supported |

- Scope each stage's release secrets to its **own** Environment, not the repo, so they are only exposed
  after that stage's approval. Do not mix SonarCloud credentials with signing/release credentials.
- Restrict all three Environments' deployments to `main` and the `ios-v*` tags. Keep workflow
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
- **App Store** for production: select the **same** TestFlight-tested build for the App Store version via
  `upload_to_app_store`, submitted for review then released in phases. Uploading a build, submitting a
  version for review, and releasing an approved version are **three separate actions** — model them
  separately in automation and runbooks.

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
- **Release** (`.github/workflows/ios-release.yml`) — tag/`workflow_dispatch`-triggered; runs the Fastlane
  `beta`/`release` lanes behind the gated Environments above.
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
  gated Environments** (`mobile-internal-beta` / `mobile-uat` / `mobile-production`) — each stage exposing
  only the credentials it needs (internal-distribution, UAT-distribution and production credentials are
  kept separate).
- Typical secrets: `APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`,
  `APP_STORE_CONNECT_API_KEY_BASE64`, and (if using Match) `MATCH_PASSWORD` +
  `MATCH_GIT_BASIC_AUTHORIZATION`; plus `SONAR_TOKEN`.
- Non-sensitive build configuration belongs in **`.xcconfig`** files committed to the repo; inject
  sensitive values at build time from CI. Document every config key in the config file and the README.
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
  version → build number → archive/IPA checksums → App Store Connect build → TestFlight groups &
  sign-off → App Store version & release status**.

## Real-device testing & data residency (optional maturity step)

Simulator suites in CI cover broad automation; a cloud real-device service (e.g. **BrowserStack App
Automate**) may supplement — not replace — simulators and human UAT for hardware, OS-version, network,
offline and compatibility scenarios. It is **subject to procurement and security approval**. Because a
real cloud device processes app data **in memory** even though nothing is persisted there and the backend
stays **UK-hosted**, the **cloud devices used must be UK-located** to satisfy data-residency requirements.
Record adoption and the residency constraint as an **ADR**.

## Architecture decision records (create/update before privileged automation)

Record at least these as ADRs under `docs/adr/` **before** building the release pipeline:

1. GitHub Actions + Fastlane as the iOS delivery architecture (and the native-app exception).
2. **Configuration strategy & environment promotion** (runtime vs build-time — drives the build/release
   model; resolve first).
3. Code-signing strategy and signing-asset custody.
4. Application bundle-ID and environment model (reconciled with the current project settings).
5. Internal & external TestFlight distribution model (three gated Environments).
6. Build-once and immutable promotion policy.
7. Cloud real-device testing platform and UK data residency, if adopted.
8. Production approval and phased-release policy.

## Definition of Done (pipeline changes)

- [ ] Workflow YAML is valid, least-privilege (`permissions:`), and pins Actions (full commit SHA) + tool versions
- [ ] Secrets are Environment-scoped per stage, never committed, never logged
- [ ] Trunk-based/tag-driven model preserved — no release branch introduced
- [ ] Marketing version derives from the tag; build number from the **release** `GITHUB_RUN_NUMBER` (no App Store Connect query); `GitCommitSHA` embedded as traceability metadata
- [ ] All three Environments (`mobile-internal-beta`, `mobile-uat`, `mobile-production`) remain gated by manual approval, with self-approval prevented where supported
- [ ] Build-once-and-promote preserved (same App Store Connect build through internal QA → UAT → production; no rebuild) — or, under build-time config, promotion of a fixed source commit is evidenced
- [ ] SonarCloud quality gate wired and passing; coverage reported
- [ ] CodeQL and Dependabot maintained as their own separate files
- [ ] Signing uses App Store Connect API key + temporary keychain; assets never committed
- [ ] Configuration-strategy, bundle-ID and signing decisions recorded as ADRs; README updated for any new pipeline, secret, environment or signing decision
- [ ] No Android tooling added to this iOS-only repo
