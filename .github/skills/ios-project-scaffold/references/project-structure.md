# Reference: project structure

A clean, testable, DEFRA-aligned SwiftUI layout. Adapt to any existing repo conventions.

```
mmo-cr-ios/
├── MMOCatchRecording.xcodeproj / .xcworkspace
├── MMOCatchRecording/
│   ├── App/
│   │   ├── MMOCatchRecordingApp.swift     # @main entry
│   │   ├── AppDependencies.swift          # DI composition root
│   │   └── AppEnvironment.swift           # env selection (dev/staging/prod)
│   ├── Features/
│   │   └── CatchRecording/
│   │       ├── Views/                     # SwiftUI views (small, composable)
│   │       ├── ViewModels/                # @MainActor observable view models
│   │       └── Models/                    # feature-scoped models
│   ├── Core/
│   │   ├── Networking/                    # APIClient, Endpoint, DTOs, error mapping
│   │   ├── Persistence/                   # local store, SyncEngine, offline mutation queue, migrations
│   │   ├── Models/                        # shared domain models
│   │   └── DesignSystem/                  # accessible components, colours, typography, spacing
│   ├── Resources/
│   │   ├── Assets.xcassets
│   │   ├── Localizable.xcstrings
│   │   └── Info.plist
│   └── Support/
│       ├── Logging/                       # OSLog wrappers, debug log level, diagnostics export
│       └── Extensions/
├── Config/
│   ├── Debug.xcconfig
│   ├── Staging.xcconfig
│   └── Release.xcconfig
├── Tests/                                 # unit tests mirror source tree
├── UITests/                               # XCUITest + accessibility tests
├── fastlane/                              # Fastfile, Appfile, Matchfile
├── ci_scripts/                            # Xcode Cloud hooks (ci_post_clone.sh)
├── .github/workflows/                     # GitHub Actions
├── docs/
│   ├── adr/                               # Architecture Decision Records (incl. native-app exception)
│   ├── solution-overview.md
│   └── architecture.md
├── .swiftlint.yml (optional)
├── Gemfile
└── README.md
```

## Notes
- **One folder per feature** under `Features/`, each self-contained (View + ViewModel + models + tests).
- **Core** holds cross-cutting concerns. Depend on protocols; inject via `AppDependencies`.
- **Persistence** is the offline source of truth; `SyncEngine` reconciles with the REST API and flushes a
  queued list of mutations on reconnect, with explicit conflict resolution.
- **DesignSystem** components must be accessible by default (Dynamic Type, labels, contrast, 44×44pt).
- **Config/*.xcconfig** carry non-sensitive per-environment values (endpoints, display name, bundle id
  suffix). Secrets are injected at build time from CI, never committed.
- **docs/adr/0001-native-ios-exception.md** should capture the agreed exception to the DEFRA
  "don't build native apps" mobile standard.
