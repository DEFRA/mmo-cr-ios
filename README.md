# MMO Catch Recording — iOS App

Native iOS (Swift/SwiftUI) app for the Marine Management Organisation's Catch Recording service,
part of DEFRA. See `.github/copilot-instructions.md` for the project's engineering standards and
`docs/adr/` for architecture decision records.

## Requirements

- Xcode (see `record-catch.xcodeproj` for the pinned deployment target — iOS 16+)
- Swift Package Manager only (no CocoaPods/Carthage)

## Build configuration

The app target is configured at build time; there is no runtime endpoint selector (ADR-0020, ADR-0021). Stage
values (such as the backend URL) are never committed: the release pipeline writes them into the `MMOCRAppConfig`
Info.plist dictionary from GitHub Environment variables.

| File | Purpose |
|---|---|
| `Config/Base.xcconfig` | Shared settings for every build configuration; includes the optional `Config/Local.xcconfig` |
| `Config/Local.xcconfig.example` | Copy to `Config/Local.xcconfig` (git-ignored) to set local values, e.g. `CR_APP_CFG_API_BASE_URL` (defaults to `http://localhost:3002`) |
| `Config/Info.plist` | Release Info.plist template: `MMOCRAppConfig` only, no ATS exception |
| `Config/Info-Debug.plist` | Debug Info.plist template: `MMOCRAppConfig` plus a `localhost`-scoped ATS exception |
| `Config/app-config.schema.json` | Allow-list of `MMOCRAppConfig` keys |

Both templates rely on `GENERATE_INFOPLIST_FILE = YES` staying enabled, so the target's existing
`INFOPLIST_KEY_*` build settings (Face ID usage description, scene manifest, orientations, export
compliance; `NSLocalNetworkUsageDescription` on Debug only) continue to merge into the generated Info.plist.

### Running against a local reference-data backend

1. Copy `Config/Local.xcconfig.example` to `Config/Local.xcconfig` (it points at `http://localhost:3002`).
2. Start your local reference-data backend.
3. If it requires a bearer token, set `REFERENCE_DATA_API_TOKEN` in the `record-catch` scheme's Run
   environment variables (Xcode: **Product ▸ Scheme ▸ Edit Scheme… ▸ Run ▸ Arguments**). The scheme
   already declares the key with an empty value; fill it in locally and never commit a real value.
4. Build and run the Debug configuration as normal.

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
