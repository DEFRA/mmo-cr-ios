# Release management: development → production (iOS)

This reference describes the end-to-end release flow the pipeline implements for the MMO Catch Recording
iOS app. It is **iOS-only** and assumes **trunk-based development with tag-driven releases** — there are
**no release branches**. See [ci-cd.instructions.md](../../../instructions/ci-cd.instructions.md) for the
governing standards.

## Roles (small team)
- **Developer** — writes app code on short-lived feature branches, opens PRs into `main`.
- **Internal QA** — smoke/exploratory validation on each app's internal TestFlight group.
- **UAT (business users)** — acceptance testing on the **Test** app's external TestFlight group.
- **DevOps** — owns the pipeline, cuts release tags, approves the gated Environments, monitors production.

## The flow

```
1. Develop        feature/* branch  ──PR──▶  main
                    PR CI: SwiftLint · build · unit/UI tests + coverage · SonarCloud (PR)
                    Native gates: CodeQL · Dependabot · secret scanning + push protection
                    Branch protection: green CI + review required to merge

2. Integrate      merge to main (trunk, always releasable)
                    main CI: full tests + SonarCloud (main) + automated tag creation

3. Cut a release  automated tag  vX.Y.Z-BUILD_N  on main
                    marketing version = X.Y.Z (from project / tag)
                    build number      = N (from project / tag)
                    GitCommitSHA      = read-only Info.plist metadata (traceability only)

4. Dev            [env: dev — no gate]
                    build+sign the Dev app (mmo.catchrecordingdev.ios) from the tagged commit
                    upload_to_testflight → Dev internal group

5. Test           [env: test — APPROVAL A] build+sign the Test app (mmo.catchrecordingtest.ios) ──▶
                    upload_to_testflight → Test internal group  (smoke / exploratory sign-off)
                  [env: test-external — APPROVAL B] assign the SAME Test build → external UAT group
                    (TestFlight Beta App Review if required; no rebuild) → business UAT sign-off

6. Prod           [env: prod — APPROVAL C] build+sign the Prod app (mmo.catchrecording.ios) ──▶
                    upload_to_testflight → Prod internal group  (production-identity smoke)
                  [env: prod-external — APPROVAL D] assign the SAME Prod build → external group (no rebuild)

7. Production     [env: prod-appstore — APPROVAL E]
                    submit the SAME Prod build → upload_to_app_store → review → PHASED RELEASE

8. Monitor        App Store Connect metrics + crash reporting during the phased roll-out
                    pause the phased release if regressions appear

9. Hotfix         fix on main  →  new higher patch tag  vX.Y.(Z+1)
                    (no hotfix/release branch — the trunk is always releasable)
```

> **Build-per-environment from one tested commit.** The three apps have distinct bundle IDs, so a single
> binary cannot move between environments; one tag builds all three from the **same commit**. Equivalence
> is evidenced by the same commit SHA, pinned toolchain and locked dependencies, plus the Prod app's own
> internal (and, where required, external) TestFlight pass before submission. External-TestFlight promotion
> is a **no-rebuild** App Store Connect metadata action.

## Why no release branches
For a single team shipping a single live version, a release branch adds merge/maintenance overhead without
benefit. A Git tag on `main` is an immutable, auditable release point; the gated Environments provide the
control that a release branch would otherwise gate. Release branches would only be justified to stabilise a
release while `main` moves on, or to support multiple live versions in parallel — neither applies here. Any
future need is an ADR + governance discussion, not an ad hoc branch.

## Versioning rules
- **Marketing version** (`CFBundleShortVersionString`): SemVer from the tag (`v1.4.0` → `1.4.0`).
- **Build number** (`CFBundleVersion`): from the **release** `GITHUB_RUN_NUMBER`; **not** queried from App
  Store Connect. Must be **unique and higher** than the previous upload for a given marketing version
  (global cross-version monotonicity is not enforced); never reused or hand-edited.
- **Commit SHA**: embedded as read-only `Info.plist` metadata (e.g. `GitCommitSHA`) for traceability only
  — it is never the build number.

## Approval & environments
**Six** Environments — **`dev`** (ungated), **`test`** (A), **`test-external`** (B), **`prod`** (C),
**`prod-external`** (D) and **`prod-appstore`** (E) — each gated (except `dev`) by a **manual reviewer
approval** before its job runs (prevent self-approval where supported), and each scopes its release secrets
to the Environment (exposed only after that stage's approval). A stage is only reachable once the preceding
gate is approved. Restrict deployments to `main` and `v*` tags.

## Traceability
Every production build is traceable end to end: **tag → commit SHA → workflow run → marketing version →
build number → archive/IPA checksums → App Store Connect build → TestFlight groups & sign-off → App Store
version & release status**. Keep release notes tester-friendly for TestFlight ("what to test", "known
limitations").
