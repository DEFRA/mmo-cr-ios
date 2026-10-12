# MMO Catch Recording — iOS App

Native iOS (Swift/SwiftUI) app for the Marine Management Organisation's Catch Recording service,
part of DEFRA. See `.github/copilot-instructions.md` for the project's engineering standards and
`docs/adr/` for architecture decision records.

## Requirements

- Xcode (see `record-catch.xcodeproj` for the pinned deployment target — iOS 16+)
- Swift Package Manager only (no CocoaPods/Carthage)

## Build configuration

The app target is configured at build time via `.xcconfig` files (no runtime endpoint selector —
see ADR-0018 and `.github/instructions/ci-cd.instructions.md`'s frozen build-time configuration
decision):

| File | Purpose |
|---|---|
| `record-catch/Config/Debug.xcconfig` | `API_BASE_URL` for Debug builds — the CDP **dev** environment's reference-data API (`https://mmo-cr-catch-recording-service.api.dev.cdp-int.defra.cloud/reference-data-service`) |
| `record-catch/Config/Release.xcconfig` | `API_BASE_URL` for Release builds (placeholder HTTPS endpoint pending a real production API) |
| `record-catch/Resources/Info-Debug.plist` | Debug-only Info.plist additions: `APIBaseURL` only — no ATS exception (Debug is HTTPS-only; see ADR-0018's 2026-10 CDP dev addendum) |
| `record-catch/Resources/Info-Release.plist` | Release-only Info.plist additions: `APIBaseURL` only — no ATS exception, no local-network key |

Both plist files rely on `GENERATE_INFOPLIST_FILE = YES` staying enabled, so the target's existing
`INFOPLIST_KEY_*` build settings (Face ID usage description, scene manifest, orientations, export
compliance) continue to merge into the generated Info.plist alongside these additions.

### Running against the CDP dev reference-data API

1. Debug builds point at the CDP **dev** environment by default — no local backend needed.
2. The API requires a bearer token. Set `REFERENCE_DATA_API_TOKEN` as a Run environment variable
   on your own **personal, non-shared** Xcode scheme (Xcode: **Product ▸ Scheme ▸ Manage
   Schemes… ▸ duplicate `record-catch` ▸ untick Shared ▸ Edit Scheme… ▸ Run ▸ Arguments**). Never
   set it on the shared `record-catch` scheme — that scheme is committed to source control.
3. Build and run the Debug configuration as normal.
4. For BrowserStack App Automate XCUITest runs, pass the token via the build API's
   `setEnvVariables` parameter (sourced from a CI secret, never committed) — UI tests relay it to
   the app under test via `XCUIApplication.forwardReferenceDataAPIToken()`
   (`record-catchUITests/XCUIApplication+ReferenceDataToken.swift`), since BrowserStack's
   `setEnvVariables` reaches only the test runner process, not the launched app.

See `docs/api/reference-data-api.md` for the full endpoint/envelope reference, physical-device (LAN
IP) testing instructions, and the developer smoke-check entry point.

## Testing

- Unit tests: `record-catchTests` (XCTest)
- UI tests: `record-catchUITests` (XCUITest)
- Run via Xcode, `xcodebuild test`, or `fastlane test` (see `fastlane/README.md`)

## Architecture decision records

See `docs/adr/` for the full history of architecture decisions, including:

- ADR-0001 — app architecture pattern
- ADR-0004 — port selection API-shaped stub seam
- ADR-0018 — reference data API connector and build-time configuration
