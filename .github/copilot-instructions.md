# MMO Catch Recording — iOS App (Project Guidelines)

This repository holds the source code for the **MMO Catch Recording** native iOS application for
the Marine Management Organisation, part of the Department for Environment, Food and Rural
Affairs (**DEFRA**).

These guidelines apply to **every** chat request in this workspace and are inherited by custom
agents (including [iOS Developer](.github/agents/ios-developer.agent.md),
[iOS Planner](.github/agents/ios-planner.agent.md) and
[iOS DevOps](.github/agents/ios-devops.agent.md)).

---

## 1. Standards precedence (highest wins)

When guidance conflicts, follow this order:

1. **DEFRA Software Development Standards** (mandatory) — https://defra.github.io/software-development-standards/
2. **DEFRA Digital Service Manual** — https://digital.defra.gov.uk/service-manual
3. **GOV.UK Service Standard & Service Manual (GDS)** — https://www.gov.uk/service-manual
4. **Apple** — Human Interface Guidelines, Swift API Design Guidelines, App Store Review Guidelines
5. **Community best practice** — OWASP MASVS, widely-adopted SwiftUI patterns

> **DEFRA takes precedence over GDS. GDS takes precedence over Apple/community guidance.**
> Any deviation from a DEFRA standard MUST be raised as a formal exception through DEFRA's
> architectural governance (Delivery Architecture team: `delivery.architecture@defra.gov.uk`).

## 2. ⚠️ Known requirement gap — native iOS vs DEFRA mobile standard

DEFRA's [Mobile application standards](https://defra.github.io/software-development-standards/standards/mobile_app_standards/)
define a **preference hierarchy** (off-the-shelf → Power App → Progressive Web App → cross-platform
Flutter/React Native) and state **"Don't build native apps"** except as a governed exception.

This repository builds a **native iOS (Swift/SwiftUI)** app. Agents MUST:
- Treat the native decision as an **agreed architectural exception** and remind the team to record it
  as an Architecture Decision Record (ADR) and log it with the Delivery Architecture team if not
  already done.
- Still enforce every DEFRA mobile requirement that applies to native apps (offline-first, encryption
  in transit, error logging, data-at-rest protection, device/beta testing, MDM/App Store
  distribution). See [security](.github/instructions/security.instructions.md) and
  [ci-cd](.github/instructions/ci-cd.instructions.md) instructions.

## 3. Mandatory DEFRA constraints (apply to all work)

- **Offline-first.** Assume the app must remain useful with no connectivity; degrade gracefully and sync
  when back online. Field workers operate in remote coastal/rural locations.
- **Encrypt all traffic** (HTTPS/TLS). Never send data over plain HTTP. Follow ATS.
- **Protect data at rest** on the device (Keychain for secrets, encrypted storage for sensitive data).
- **Log errors** so a user can share diagnostics for support; support a debug logging level.
- **Code in the open** in the [DEFRA GitHub org](https://github.com/DEFRA); analyse quality/coverage in
  [DEFRA SonarCloud](https://sonarcloud.io/organizations/defra).
- **Never commit secrets.** Follow DEFRA's
  [credential exposure](https://defra.github.io/software-development-standards/processes/credential_exposure/) process if a secret leaks.
- **Accessibility is a legal requirement:** meet **WCAG 2.2 level AA** and work with common assistive
  technologies (see [accessibility](.github/instructions/accessibility.instructions.md)).
- **Secure by Design** (https://www.security.gov.uk/guidance/secure-by-design/principles/).
- Maintain a README to DEFRA
  [README standards](https://defra.github.io/software-development-standards/standards/readme_standards/),
  plus a solution overview, ADRs and architecture diagrams.

## 4. The working framework (Triage → Read → Research → Plan Handoff → Plan Validation Research → Approval → Implement → Test → Iterate)

This section is the **single source of truth** for the working loop. Custom agents reference it and
**must not restate or fork it**.

**Triage first — pick the right path by size and risk:**

- **Trivial / low-risk** (typo, copy/comment/doc tweak, a small localised change with no impact on
  architecture, networking, persistence/sync, auth, security or accessibility): skip the planner and
  heavy research. Do a light **Read → Implement → Test → Summarise**, and research only the specific
  point that is genuinely uncertain.
- **Non-trivial** (new feature, architecture, networking, persistence/sync, auth, security, an
  accessibility surface, or anything user-visible or risky): run the full loop below.

Non-trivial loop:

1. **Read** — Read the relevant files/config in the repo for context before acting. Never assume; verify.
2. **Research** — Do a thorough internet research in the open, **scoped to the task's risk**, and validate
  findings against Apple, DEFRA/GDS, and framework guidance so advice reflects current APIs and policy.
  Cite sources.
3. **Clarify** — Ask the user targeted questions whenever requirements are ambiguous or missing.
   Surface requirement gaps explicitly with suggested fixes. Do not guess at intent.
4. **Plan handoff** — Delegate planning to the task's designated planning agent when one exists (for
  iOS app implementation, this is [iOS Planner](.github/agents/ios-planner.agent.md)). The planning
  agent returns the complete implementation plan.
5. **Plan validation research** — Perform a thorough internet research in the open to validate the plan
  against Apple, DEFRA/GDS, and framework guidance, **focusing on the steps the planner flagged as risky
  or version-sensitive** (unfamiliar APIs, security, policy). Send targeted revisions back to the planner.
6. **Approval** — Present the complete validated plan to the user and obtain explicit approval before
  implementation. If changes are requested, update the plan, re-validate, and re-approve. **Cap the
  plan → validate → approve → implement replanning cycle at 3 iterations**; if it is still unresolved,
  stop and surface the blocker to the user instead of looping.
7. **Implement** — Deliver one task at a time (or parallel independent tasks) from the approved plan.
  Stay focused on the requested outcome; do not scope-creep or refactor unrelated code. **When starting
  development on a new feature (or on this repo while it still has no app code), create the required
  ADR(s) first** — architecture pattern, offline persistence choice, and the native-app exception — under
  `docs/adr/`, then build against them.
8. **Test / Validate** — Build, run unit/UI/accessibility tests, check errors, and confirm each task
  works before moving on.
9. **Iterate** — Refine until the user is satisfied with each task.
10. **Summarise** — End with a detailed **executive summary** of what changed, why, how it was validated,
  and any follow-ups or risks.

## 5. Tech stack (current decisions)

- **Language/UI:** Swift + SwiftUI (SwiftUI-first). Minimum deployment target **iOS 16**.
- **Architecture:** Not yet fixed. If the repo already contains boilerplate, read it and follow the
  established pattern. If not, **ask the developer** which pattern to adopt (e.g. MVVM + Swift
  Concurrency) before scaffolding. Record the choice as an ADR.
- **Dependencies:** **Swift Package Manager only** (no CocoaPods/Carthage).
- **Concurrency:** Swift Concurrency (`async/await`, actors). Avoid completion-handler pyramids.
- **CI/CD:** GitHub Actions, fastlane, Xcode Cloud and TestFlight are all first-class — see the
  [iOS DevOps agent](.github/agents/ios-devops.agent.md).

## 6. Build & test commands

Prefer running via fastlane once configured. Common commands:

- Build: `xcodebuild build -scheme <Scheme> -destination 'platform=iOS Simulator,name=iPhone 15'`
- Test: `xcodebuild test -scheme <Scheme> -destination 'platform=iOS Simulator,name=iPhone 15'`
- fastlane (once set up): `fastlane test`, `fastlane beta`, `fastlane release`

See [ci-cd instructions](.github/instructions/ci-cd.instructions.md) and the
[release pipeline skill](.github/skills/ios-release-pipeline/SKILL.md).

## 7. Conventions

- Follow the [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/):
  clarity at the point of use, `UpperCamelCase` types, `lowerCamelCase` members, no needless words.
- Keep views small and composable; push logic out of views into view models/services.
- Use `swift-format`/SwiftLint if configured; do not fight the formatter.
- Conventional, descriptive commits; small PRs; follow DEFRA
  [pull request](https://defra.github.io/software-development-standards/processes/pull_requests/) and
  [version control](https://defra.github.io/software-development-standards/standards/version_control_standards/) standards.
