---
description: "Accessibility standards (WCAG 2.2 AA, DEFRA/GDS legal requirement, Apple HIG) for the MMO Catch Recording iOS app. Use when building UI, reviewing SwiftUI views, or auditing VoiceOver, Dynamic Type, contrast, tap targets and assistive technology support."
applyTo: **/*.swift
---

# Accessibility standards (legal requirement)

Meeting accessibility is a **legal requirement** for DEFRA services under the Public Sector Bodies
(Websites and Mobile Applications) Accessibility Regulations 2018 and the Equality Act 2010. The app
**must meet [WCAG 2.2 level AA](https://www.gov.uk/service-manual/helping-people-to-use-your-service/understanding-wcag)**
and work with common assistive technologies. This applies even to staff-facing/internal apps.

References: [DEFRA accessibility](https://digital.defra.gov.uk/accessibility) ·
[GDS testing for accessibility](https://www.gov.uk/service-manual/technology/testing-for-accessibility) ·
[Apple HIG Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility).

## Build accessibility in from the start

Consider it at every stage (design → code → test), not as a retrofit. Fixing late is far more expensive.

## Vision

- **Dynamic Type:** Use system text styles (`.font(.body)` etc.) and support enlargement to at least
  200%. Never hard-code font sizes that cannot scale. Test at the largest accessibility sizes and ensure
  layouts reflow (use `ScrollView`, avoid truncation/clipping).
- **Contrast:** Meet WCAG AA — **4.5:1** for normal text, **3:1** for large (≥18pt or bold ≥14pt) text
  and meaningful UI/graphics. Prefer system semantic colours that adapt to Dark Mode and Increase Contrast.
- **Don't rely on colour alone:** Pair colour with text, icon or shape to convey state (e.g. error =
  red + icon + message).

## VoiceOver & assistive tech

- Give every meaningful control an accessibility **label**; add **hint**, **value** and **traits** where
  needed (`.accessibilityLabel`, `.accessibilityValue`, `.accessibilityHint`, `.accessibilityAddTraits`).
- Group related elements (`.accessibilityElement(children: .combine)`); hide decorative images
  (`.accessibilityHidden(true)`).
- Ensure a logical focus order and that custom controls announce their role and state.
- Support VoiceOver, Voice Control, Switch Control and Full Keyboard Access. Label elements so Voice
  Control's "tap <label>" works.

## Mobility

- **Tap targets ≥ 44×44 pt** with adequate spacing (~ enough padding to avoid mis-taps).
- Offer non-gesture alternatives to every gesture (e.g. a visible button as well as swipe-to-delete).
- Avoid custom multi-finger gestures for core actions.

## Cognitive & motion

- Keep flows simple and consistent; break multi-step tasks into single-purpose screens.
- Avoid time-boxed auto-dismissing UI; prefer explicit dismissal.
- Respect **Reduce Motion** (`@Environment(\.accessibilityReduceMotion)`) — replace large animations with
  fades; avoid parallax/zoom when reduced.
- Confirm destructive/irreversible actions.

## SwiftUI checklist

- [ ] All interactive elements have labels/traits and are reachable by VoiceOver.
- [ ] Layout works with the largest Dynamic Type size without clipping.
- [ ] Contrast meets AA in light and dark appearance.
- [ ] No information conveyed by colour alone.
- [ ] Tap targets ≥ 44×44 pt.
- [ ] Reduce Motion respected.
- [ ] Errors are perceivable (text + icon), announced, and describe how to fix.

## Testing (do both automated and manual)

- **Automated:** Accessibility Inspector audits; XCUITest assertions on accessibility identifiers/labels.
- **Manual:** Navigate the whole app with VoiceOver; test at max Dynamic Type; test Increase Contrast,
  Reduce Motion, Voice Control and Switch Control.
- Get a **formal accessibility audit and fix issues before public beta**, and publish an accessibility
  statement. See the [ios-accessibility-audit skill](../skills/ios-accessibility-audit/SKILL.md).
