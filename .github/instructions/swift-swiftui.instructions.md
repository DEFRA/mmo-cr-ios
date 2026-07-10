---
description: "Swift and SwiftUI coding standards for the MMO Catch Recording iOS app: API design guidelines, SwiftUI-first patterns, MVVM, Swift Concurrency, project layout, offline-first data. Use when writing or reviewing Swift/SwiftUI code."
applyTo: **/*.swift
---

# Swift & SwiftUI standards

Precedence: DEFRA standards > GDS > Apple/Swift guidelines. Where DEFRA is silent, follow the
[Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/) and Apple's
SwiftUI guidance.

## Language & style

- **Naming:** Clarity at the point of use. `UpperCamelCase` for types/protocols, `lowerCamelCase` for
  members. Omit needless words; name by role, not type. Booleans read as assertions (`isValid`,
  `hasCatch`). Methods with side effects use imperative verbs (`save()`); pure ones read as nouns
  (`distance(to:)`).
- **Value types first:** Prefer `struct`/`enum` over `class`. Use `class`/`actor` only when reference
  semantics or shared mutable state is genuinely required.
- **Immutability:** Prefer `let`. Keep optionals meaningful; avoid force-unwrap (`!`) and
  `try!`/`as!` outside tests. Handle `nil` and errors explicitly.
- **Errors:** Use typed `Error` enums and `throws`; never swallow errors silently (see logging).
- **Docs:** Write a `///` summary for public/non-obvious declarations.
- **Formatting:** Use `swift-format` or SwiftLint if configured; do not fight the formatter.
- **Minimum target:** iOS 16. Guard newer APIs with `if #available`.

## SwiftUI architecture

- **SwiftUI-first.** Drop to UIKit/`UIViewRepresentable` only when SwiftUI cannot do the job; isolate it.
- **Small, composable views.** Extract subviews; a `body` should be readable at a glance. No business
  logic in views.
- **Unidirectional state.** Views render state and send intents. Keep logic in view models/services.
- **State tools:** `@State` for local view state, `@Binding` for shared child state,
  `@Observable`/`ObservableObject` for view models, `@Environment` for dependencies. Avoid massive
  view models — split by responsibility.
- **Navigation:** Use `NavigationStack` with a typed, testable navigation/route model.

## Architecture pattern

- If the repo already establishes a pattern, **follow it**. If none exists, **ask the developer** which
  to adopt (default recommendation: **MVVM + Swift Concurrency**, with a thin service/repository layer).
  Record the decision as an ADR under `docs/adr/`.
- Layer responsibilities: **View** (SwiftUI) → **ViewModel** (state + intents) → **Service/Repository**
  (domain + IO) → **Networking/Persistence**. Depend on protocols; inject dependencies for testability.

## Concurrency

- Use **Swift Concurrency** (`async/await`, `Task`, `actor`, `AsyncSequence`). Avoid nested completion
  handlers.
- Annotate UI-facing types with `@MainActor`. Do IO/CPU work off the main actor.
- Protect shared mutable state with `actor`s. Avoid data races; prefer `Sendable` types across boundaries.

## Offline-first data (mandatory)

- Treat the network as unavailable by default. Every feature must degrade gracefully offline and sync
  when back online.
- Persist locally (e.g. SwiftData/Core Data or a well-tested store) as the source of truth for offline
  use; reconcile with the backend REST API deliberately (define conflict resolution).
- Represent load/empty/error/offline states explicitly in the UI. Never show a spinner forever.
- Networking layer: typed requests/responses with `Codable`, ret/backoff and timeouts, and an offline
  queue for mutations (create/update catch records) that flush on reconnect.

## Dependencies

- **Swift Package Manager only.** No CocoaPods/Carthage. Vet packages per DEFRA
  [choosing packages](https://defra.github.io/software-development-standards/guides/choosing_packages/) —
  prefer well-maintained, licence-compatible, minimal dependencies. Pin versions.

## Suggested project layout

```
MMOCatchRecording/
├── App/                 # App entry, DI composition root, app-level config
├── Features/            # One folder per feature (Views + ViewModels + models)
├── Core/
│   ├── Networking/      # API client, endpoints, DTOs
│   ├── Persistence/     # Local store, sync engine, migrations
│   ├── Models/          # Domain models
│   └── DesignSystem/    # Reusable accessible components, colours, typography
├── Resources/           # Assets, localisations, Info.plist
└── Support/             # Logging, extensions, utilities
Tests/                   # Unit tests mirror the source tree
UITests/                 # XCUITest + accessibility tests
```
