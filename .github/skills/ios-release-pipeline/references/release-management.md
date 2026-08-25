# Release management: development → production (iOS)

This reference describes the end-to-end release flow the pipeline implements for the MMO Catch Recording
iOS app. It is **iOS-only** and assumes **trunk-based development with tag-driven releases** — there are
**no release branches**. See [ci-cd.instructions.md](../../../instructions/ci-cd.instructions.md) for the
governing standards.

## Roles (small team)
- **Developer** — writes app code on short-lived feature branches, opens PRs into `main`.
- **Internal QA** — smoke/exploratory validation of the release candidate on the internal TestFlight group.
- **UAT (business users)** — acceptance testing of the **same** build on the external TestFlight group.
- **DevOps** — owns the pipeline, cuts release tags, approves the three gated Environments, monitors production.

## The flow

```
1. Develop        feature/* branch  ──PR──▶  main
                    PR CI: SwiftLint · build · unit/UI tests + coverage · SonarCloud (PR)
                    Native gates: CodeQL · Dependabot · secret scanning + push protection
                    Branch protection: green CI + review required to merge

2. Integrate      merge to main (trunk, always releasable)
                    main CI: full tests + SonarCloud (main) + quality gate

3. Cut a release  push tag  ios-vX.Y.Z  on main
                    marketing version = X.Y.Z (from tag)
                    build number      = release GITHUB_RUN_NUMBER (no App Store Connect query)
                    GitCommitSHA      = read-only Info.plist metadata (traceability only)

4. Build once     Fastlane build_release: build → sign (App Store Connect API key) ONCE
                    the resulting App Store Connect build is promoted unchanged through every gate below

5. Internal QA    Environment: mobile-internal-beta  ── MANUAL APPROVAL ──▶
                    upload_to_testflight → internal QA group
                    smoke / exploratory sign-off

6. External UAT   Environment: mobile-uat  ── MANUAL APPROVAL ──▶
                    distribute the SAME build → external UAT group (TestFlight Beta App Review if required)
                    business UAT sign-off (no rebuild)

7. Production     Environment: mobile-production  ── MANUAL APPROVAL ──▶
                    select the SAME build → upload_to_app_store → submit for review → PHASED RELEASE

8. Monitor        App Store Connect metrics + crash reporting during the phased roll-out
                    pause the phased release if regressions appear

9. Hotfix         fix on main  →  new higher patch tag  ios-vX.Y.(Z+1)
                    (no hotfix/release branch — the trunk is always releasable)
```

> **Build-once-and-promote holds only under runtime configuration (Option A).** If the app uses build-time
> configuration (Option B), the production step is a controlled **rebuild from the exact UAT-approved
> commit**, evidenced by equivalence (same commit SHA, pinned toolchain, locked dependencies) rather than
> an identical-binary guarantee.

## Why no release branches
For a single team shipping a single live version, a release branch adds merge/maintenance overhead without
benefit. A Git tag on `main` is an immutable, auditable release point; the gated Environments provide the
control that a release branch would otherwise gate. Release branches would only be justified to stabilise a
release while `main` moves on, or to support multiple live versions in parallel — neither applies here. Any
future need is an ADR + governance discussion, not an ad hoc branch.

## Versioning rules
- **Marketing version** (`CFBundleShortVersionString`): SemVer from the tag (`ios-v1.4.0` → `1.4.0`).
- **Build number** (`CFBundleVersion`): from the **release** `GITHUB_RUN_NUMBER`; **not** queried from App
  Store Connect. Must be **unique and higher** than the previous upload for a given marketing version
  (global cross-version monotonicity is not enforced); never reused or hand-edited.
- **Commit SHA**: embedded as read-only `Info.plist` metadata (e.g. `GitCommitSHA`) for traceability only
  — it is never the build number.

## Approval & environments
**Three** Environments — **`mobile-internal-beta`**, **`mobile-uat`** and **`mobile-production`** — each
require a **manual reviewer approval** before their job runs (prevent self-approval where supported), and
each scopes its release secrets to the Environment (exposed only after that stage's approval). A stage is
only reachable once the preceding gate is approved. Restrict deployments to `main` and `ios-v*` tags.

## Traceability
Every production build is traceable end to end: **tag → commit SHA → workflow run → marketing version →
build number → archive/IPA checksums → App Store Connect build → TestFlight groups & sign-off → App Store
version & release status**. Keep release notes tester-friendly for TestFlight ("what to test", "known
limitations").
