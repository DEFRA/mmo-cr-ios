# ADR 0001 — App architecture pattern (SwiftUI + lightweight `@Observable` view model + pure helpers)

- Status: Accepted
- Date: 2026-07
- Deciders: iOS engineering
- Context tags: architecture, native-iOS, DEFRA governance

## Context

The DEFRA / MMO Catch Recording app is a **native iOS** application built in Swift + SwiftUI.
DEFRA's default technology standards favour web delivery (GOV.UK Design System, progressive
enhancement). Building a native iOS app is therefore an **architectural exception** to the
default DEFRA position and must be recorded and — per `copilot-instructions.md §2` — **logged
with the DEFRA Delivery Architecture function as a governance exception**. This ADR records both
the exception and the in-app architecture pattern we adopt.

## Decision

### 1. Native iOS is a recorded architectural exception

We deliver a native SwiftUI app (offline-first field use, camera/geolocation, on-device catch
recording at sea with no connectivity). This deviates from the DEFRA web-first default and
**must be raised as a governance exception with DEFRA Delivery Architecture**. This ADR is the
local record; it does not replace that governance step.

### 2. In-app pattern: SwiftUI-first + lightweight `@Observable` view models + pure helpers

- **Views** are small, composable SwiftUI `View` value types. Screen layout is composed from the
  shared design system (`AppColors`, `AppTypography`, `AppSpacing`) and reusable components
  (`ViewTemplate`, `TextInputField`, `PrimaryButton`, …).
- **View models** are `@Observable @MainActor final class` types that hold UI state and orchestrate
  behaviour. They stay thin: they delegate decision logic to pure helpers.
- **Pure helpers** are stateless `enum`/`struct` types with `static` functions (e.g.
  `SignInValidation`) and typed `Error`/result enums. These are trivially unit-testable with no
  UI, no async and no I/O, which supports the project coverage targets (≥95% on core logic).
- **Value types first**, `let` by default, no force-unwraps in production code, typed error enums.

This mirrors the existing codebase (see `TextInputField`'s pure static helpers) and keeps testable
logic out of SwiftUI view bodies.

## Consequences

- Business/validation logic is covered by fast, deterministic unit tests.
- Views remain declarative and thin; state is observable and predictable on the main actor.
- The native-app decision carries a **standing governance obligation**: keep the DEFRA Delivery
  Architecture exception current as scope grows (auth, networking, offline sync will each warrant
  their own ADRs).
