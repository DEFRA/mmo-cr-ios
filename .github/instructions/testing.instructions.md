---
description: "Testing standards for the MMO Catch Recording iOS app: unit tests (XCTest/Swift Testing), XCUITest UI tests, accessibility tests, offline/sync tests, coverage and SonarCloud. Use when writing or reviewing tests or setting quality gates."
applyTo: **/*Tests/**/*.swift, **/*Test*.swift, **/*Tests.swift
---

# Testing standards

Follow DEFRA [quality assurance and test standards](https://defra.github.io/software-development-standards/standards/quality_assurance_standards/).
New or changed behaviour ships with tests. Track coverage in
[DEFRA SonarCloud](https://sonarcloud.io/organizations/defra) and keep the quality gate green.

## What to test

- **Unit tests** for view models, services, repositories, networking mappers, sync/offline logic and
  domain rules. Prefer fast, isolated, deterministic tests. Inject dependencies via protocols and use
  test doubles/mocks — no real network in unit tests.
- **UI tests (XCUITest)** for critical user journeys (e.g. record a catch offline → sync when online).
  Drive elements by stable **accessibility identifiers**.
- **Accessibility tests** — assert accessibility labels/traits exist; run Accessibility Inspector audits;
  include VoiceOver/Dynamic Type checks (see
  [ios-accessibility-audit skill](../skills/ios-accessibility-audit/SKILL.md)).
- **Offline/sync tests** — simulate no-connectivity, queued mutations, reconnect and conflict resolution.

## Frameworks

- **XCTest** is the baseline. **Swift Testing** (`@Test`, `#expect`) may be used where the toolchain
  supports it; keep a consistent choice per target.
- Structure tests **Arrange → Act → Assert**. One behaviour per test; descriptive names
  (`test_savingCatch_whenOffline_queuesForSync`).

## Conventions

- Mirror the source tree: `Tests/` for unit, `UITests/` for UI/accessibility.
- Make tests independent and order-agnostic; no shared mutable global state; reset state in `setUp`.
- Prefer testing behaviour/outcomes over implementation details. Avoid flaky timing — use expectations
  and controllable clocks, not `sleep`.
- Keep fixtures/sample payloads in the test bundle; do not hit live services.

## Running

- Local/CI: `xcodebuild test -scheme <Scheme> -destination 'platform=iOS Simulator,name=iPhone 15'`
  (or `fastlane test`). Every PR runs build + test + lint + SonarCloud before merge.
- Device coverage: also validate on a **representative range of real devices** and current + latest iOS
  versions per DEFRA mobile standards; enrol a device in Apple beta programmes to catch upcoming issues.
