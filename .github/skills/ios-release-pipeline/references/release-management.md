# Release management: development → production (iOS)

This reference describes the end-to-end release flow the pipeline implements for the MMO Catch Recording
iOS app. It is **iOS-only** and assumes **trunk-based development with tag-driven releases** — there are
**no release branches**. See [ci-cd.instructions.md](../../../instructions/ci-cd.instructions.md) for the
governing standards.

## Roles (small team)
- **Developer** — writes app code on short-lived feature branches, opens PRs into `main`.
- **Project QA** — sprint testing on the **Test** app's internal group (Test backend); release testing and
  performance testing on its external group (Perf-Test backend).
- **MMO QA** — UAT on the **Prod** app's internal group (Ext-Test backend).
- **Sanity testers** — final check on the **Prod** app's external group (Prod backend).
- **DevOps** — owns the pipeline, approves the gated Environments, dispatches promotions, monitors production.

## The flow

```
1. Develop        feature/* branch  ──PR──▶  main
                    PR CI: SwiftLint · build · unit/UI tests + coverage · SonarCloud (PR)
                    Native gates: CodeQL · Dependabot · secret scanning + push protection
                    Branch protection: green CI + review required to merge

2. Integrate      merge to main (trunk, always releasable)
                    main CI: full tests + SonarCloud (main) + release tag vX.Y.Z-BUILD_N on every merge
                    except Dependabot's (a manual iOS CI run with publish_release_tag=true also tags)

3. Cut a release  start iOS Release manually on the tag — its only entry point; CI never starts a release
                    marketing version = X.Y.Z, build number = N (Config/Base.xcconfig, validated vs tag)
                    GitCommitSHA      = read-only Info.plist metadata (traceability only)

4. Build          ios-release.yml — each app COMPILED ONCE, build N → internal TestFlight,
                  encrypted .xcarchive kept 90 days, Mach-O UUID recorded
                    [env: dev  — no gate]    Dev app  → Dev backend
                    [env: test — APPROVAL A] Test app → Test backend       (sprint testing)
                    [env: prod — APPROVAL C] Prod app → Ext-Test backend   (UAT)

5. Promote        ios-promote.yml (manual dispatch) — NO RECOMPILE: same archive, backend URL swapped,
                  build N.1, re-signed, proven (UUID match, codesign verify, internal host absent)
                    [env: test-external — APPROVAL B] Test app N.1 → Perf-Test → external group
                    [env: prod-external — APPROVAL D] Prod app N.1 → Prod      → external group (sanity)
                    (TestFlight Beta App Review applies to each N.1)

6. Production     [env: prod-appstore — APPROVAL E]
                    submit the SAME Prod N.1 upload → review → PHASED RELEASE (build once)

7. Monitor        App Store Connect metrics + crash reporting during the phased roll-out
                    pause the phased release if regressions appear

8. Hotfix         fix on main  →  new higher patch tag  vX.Y.(Z+1)
                    (no hotfix/release branch — the trunk is always releasable)
```

> **Compile once, configure at promotion** (ADR-0015). Internal and external builds of an app share the same
> compiled program; only `MMOAPIBaseURL` and the build number differ. The App Store receives the exact `N.1`
> upload the sanity testers used. Promotion runs in its own workflow because a GitHub run is cancelled after
> 35 days including approval waits.

## Why no release branches
For a single team shipping a single live version, a release branch adds merge/maintenance overhead without
benefit. A Git tag on `main` is an immutable, auditable release point; the gated Environments provide the
control that a release branch would otherwise gate. Release branches would only be justified to stabilise a
release while `main` moves on, or to support multiple live versions in parallel — neither applies here. Any
future need is an ADR + governance discussion, not an ad hoc branch.

## Versioning rules
- **Marketing version** (`CFBundleShortVersionString`) and **build number** `N` (`CFBundleVersion`): from
  `Config/Base.xcconfig`, validated against the tag; **not** queried from App Store Connect.
- **External promotion** uploads the same compiled code as build `N.1`.
- Every upload must be **unique and higher** than the previous upload for a given marketing version; never
  reused or hand-edited once released.
- **Commit SHA**: embedded as read-only `Info.plist` metadata (e.g. `GitCommitSHA`) for traceability only
  — it is never the build number.

## Approval & environments
**Six** Environments — **`dev`** (ungated), **`test`** (A), **`test-external`** (B), **`prod`** (C),
**`prod-external`** (D) and **`prod-appstore`** (E) — each gated (except `dev`) by a **manual reviewer
approval** before its job runs (prevent self-approval where supported). Each scopes its release secrets to
the Environment and holds exactly one backend URL (`MMO_API_BASE_URL` variable). Restrict deployments to
`main` and `v*` tags.

## Traceability
Every production build is traceable end to end: **tag → commit SHA → workflow run → marketing version →
build number (`N` / `N.1`) → Mach-O UUID → App Store Connect build → TestFlight groups & sign-off → App
Store version & release status**. Keep release notes tester-friendly for TestFlight ("what to test", "known
limitations").
