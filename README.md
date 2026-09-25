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
| `record-catch/Config/Debug.xcconfig` | `API_BASE_URL` for Debug builds (defaults to `http://localhost:3002`, a locally-running reference-data backend) |
| `record-catch/Config/Release.xcconfig` | `API_BASE_URL` for Release builds (placeholder HTTPS endpoint pending a real production API) |
| `record-catch/Resources/Info-Debug.plist` | Debug-only Info.plist additions: `APIBaseURL`, a scoped `localhost` ATS exception, and `NSLocalNetworkUsageDescription` |
| `record-catch/Resources/Info-Release.plist` | Release-only Info.plist additions: `APIBaseURL` only — no ATS exception, no local-network key |

Both plist files rely on `GENERATE_INFOPLIST_FILE = YES` staying enabled, so the target's existing
`INFOPLIST_KEY_*` build settings (Face ID usage description, scene manifest, orientations, export
compliance) continue to merge into the generated Info.plist alongside these additions.

### Running against a local reference-data backend

1. Start your local reference-data backend (default: `http://localhost:3002`).
2. If it requires a bearer token, set `REFERENCE_DATA_API_TOKEN` in the `record-catch` scheme's Run
   environment variables (Xcode: **Product ▸ Scheme ▸ Edit Scheme… ▸ Run ▸ Arguments**). The scheme
   already declares the key with an empty value; fill it in locally and never commit a real value.
3. Build and run the Debug configuration as normal.

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
