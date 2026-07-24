---
name: ios-project-scaffold
description: "Scaffold or extend the MMO Catch Recording iOS app structure: SwiftUI app skeleton, feature folders, Core layers (networking, offline persistence/sync, design system), SPM setup, config/xcconfig, ADRs and README. Use when creating the initial project, adding a new feature module, or establishing conventions."
argument-hint: "e.g. 'scaffold the initial app' or 'add a Catch Recording feature module'"
user-invocable: false
---

# iOS project scaffold

Use this skill to create a clean, DEFRA-aligned, testable SwiftUI project structure — or to add a new
feature module that matches existing conventions.

## When to use
- First-time project setup (no boilerplate yet).
- Adding a new feature module (View + ViewModel + models + tests).
- Establishing/refreshing shared Core layers and the design system.

## Before you scaffold (Read → Clarify)
1. **Read** the repo. If a project/architecture already exists, follow it — do **not** restructure.
2. **Clarify** with the developer if no pattern exists:
   - Architecture pattern (recommend **MVVM + Swift Concurrency**).
   - Persistence choice for offline (e.g. **SwiftData** for iOS 17+ paths, or Core Data for iOS 16).
   - Bundle identifier scheme and environments (dev/staging/prod).
   Record decisions as ADRs in `docs/adr/`.

## Procedure
1. Create the folder structure (see `references/project-structure.md`).
2. Add the SwiftUI app entry + a composition root for dependency injection.
3. Set up **Swift Package Manager** for dependencies (no CocoaPods/Carthage); pin versions.
4. Add `Config/` `.xcconfig` files per environment (Debug/Staging/Release) with non-sensitive values;
   inject secrets at build time from CI.
5. Stub the Core layers: `Networking` (API client + `Codable` DTOs), `Persistence` (local store + sync
   engine + offline mutation queue), `Models`, `DesignSystem` (accessible reusable components).
6. Add `Tests/` and `UITests/` targets mirroring the source tree, with at least one passing sample test.
7. Add/refresh the **README** to DEFRA
   [README standards](https://defra.github.io/software-development-standards/standards/readme_standards/),
   plus a solution overview and architecture diagram.
8. Wire SwiftLint/`swift-format` config if the team uses it.

## Standards to honour
- [swift-swiftui instructions](../../instructions/swift-swiftui.instructions.md) (patterns, layout, offline-first)
- [accessibility instructions](../../instructions/accessibility.instructions.md) (design-system components must be accessible)
- [security instructions](../../instructions/security.instructions.md) (Keychain, ATS, no secrets)

## Validate
- Project builds: `xcodebuild build -scheme <Scheme> -destination 'platform=iOS Simulator,name=iPhone 15'`.
- Sample tests pass: `xcodebuild test ...` or `fastlane test`.
- Structure matches `references/project-structure.md` and any ADRs.
