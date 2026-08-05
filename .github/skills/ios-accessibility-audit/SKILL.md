---
name: ios-accessibility-audit
description: "Audit and validate the MMO Catch Recording iOS app against WCAG 2.2 AA and Apple accessibility guidance (a DEFRA legal requirement). Use to review SwiftUI views for VoiceOver, Dynamic Type, contrast, tap targets, Reduce Motion and assistive-technology support, and to prepare for a formal audit before public beta."
argument-hint: "e.g. 'audit the Catch Recording screen for accessibility'"
user-invocable: false
---

# iOS accessibility audit

Accessibility is a **legal requirement** for DEFRA services (WCAG 2.2 AA). Use this skill to check code
and running builds, following the [accessibility instructions](../../instructions/accessibility.instructions.md).

## When to use
- Reviewing a new/changed SwiftUI view or component.
- Preparing for the **formal accessibility audit required before public beta**.
- Diagnosing a reported accessibility issue.

## Procedure

### 1. Static code review (per view)
Check each interactive element for:
- [ ] Accessibility **label** (and hint/value/traits where needed); decorative images hidden.
- [ ] System **text styles** used (Dynamic Type) — no fixed sizes that can't scale.
- [ ] **Contrast** ≥ 4.5:1 (normal) / 3:1 (large/bold) in light *and* dark; prefer semantic colours.
- [ ] Meaning never conveyed by **colour alone** (add text/icon/shape).
- [ ] Tap targets **≥ 44×44 pt** with adequate spacing.
- [ ] **Reduce Motion** respected (`@Environment(\.accessibilityReduceMotion)`).
- [ ] Stable **accessibility identifiers** for UI tests.
- [ ] Errors are perceivable, announced, and explain how to fix.

### 2. Automated checks
- Run **Accessibility Inspector** (Xcode → Open Developer Tool) audits on each screen.
- Add/extend XCUITests asserting labels/identifiers exist and states are announced.
- Run any configured linters and the DEFRA SonarCloud gate.

### 3. Manual assistive-technology testing
- Navigate the whole flow with **VoiceOver**; verify order, labels and announcements.
- Set Dynamic Type to the **largest** accessibility size; verify no clipping and layouts reflow.
- Test **Increase Contrast**, **Reduce Motion**, **Voice Control** ("tap <label>") and **Switch Control**.
- Test on a **real device** and across current + latest iOS versions (DEFRA mobile standard).

### 4. Report & fix
- List issues by WCAG success criterion with severity and a concrete fix.
- Fix, then re-run the checks. Track residual items.
- Before public beta: obtain a **formal accessibility audit**, fix issues, and publish an
  **accessibility statement**.

## Output format
Produce a short report:
- **Summary** (pass/fail against WCAG 2.2 AA).
- **Findings** table: element → criterion → severity → recommended fix.
- **Validation**: which automated/manual checks were run and their results.
- **Follow-ups**: anything deferred, with rationale.
