# SwiftLint

The project uses [SwiftLint](https://github.com/realm/SwiftLint) to enforce the
[Swift/SwiftUI coding standards](../../.github/instructions/swift-swiftui.instructions.md) —
in particular no `force_unwrapping`/`force_try`/`force_cast` in app code, and general
Swift API Design Guideline conformance (naming, complexity, structure).

## Setup (one-off, per machine)

SwiftLint is a **developer tool**, not a runtime dependency, so it's installed via Homebrew
rather than Swift Package Manager (SPM stays reserved for the app's actual dependencies, per
the project's SPM-only policy):

```sh
brew install swiftlint
```

## Running it

```sh
scripts/swiftlint.sh          # lint (used by CI)
scripts/swiftlint.sh --fix    # auto-correct fixable violations locally
```

The script lints three scopes separately, each with its own config, because SwiftLint's
`--config` flag **replaces** rather than merges with a parent config:

| Scope                | Config                              | Notes                                                                 |
| --------------------- | ------------------------------------ | ---------------------------------------------------------------------- |
| App source            | `.swiftlint.yml` (repo root)         | Strict — `force_unwrapping`/`force_try`/`force_cast` are **errors**.   |
| `record-catchTests`   | `record-catchTests/.swiftlint.yml`   | Force-unwrap/try/cast permitted; short identifier/type names (test fixtures) allowed. |
| `record-catchUITests` | `record-catchUITests/.swiftlint.yml` | As above, plus the `ID` accessibility-identifier enum convention allowed. |

## Baselines (legacy code adoption)

SwiftLint was introduced after a substantial amount of code already existed. Rather than mass-editing
unrelated files to satisfy the new rules in one large change, each scope has a committed **baseline**
under `.swiftlint-baselines/*.json`, generated with `--write-baseline` at the point SwiftLint was
added. The baseline grandfathers the violations that already existed at that point — **but any new
violation still fails lint/CI**.

To shrink the baseline over time:

1. Fix a pre-existing violation (e.g. a long line, an overly complex function).
2. Regenerate that scope's baseline, e.g.:
   ```sh
   swiftlint lint --config .swiftlint.yml --write-baseline .swiftlint-baselines/app.json record-catch
   ```
3. Commit the updated baseline file alongside the fix.

## Xcode build integration (manual, one-off)

Hand-editing `record-catch.xcodeproj/project.pbxproj` to add a Run Script build phase proved
unreliable in automated tooling — Xcode fully re-serialises and validates the project file on
build/package-resolution, and silently drops build phases it doesn't recognise as well-formed. This
is safest done once, by hand, in Xcode:

1. Select the **record-catch** target → **Build Phases** → **+** → **New Run Script Phase**.
2. Name it `Run SwiftLint` and drag it above **Compile Sources**.
3. Paste:
   ```sh
   if command -v swiftlint >/dev/null 2>&1; then
     swiftlint lint --strict --config "${SRCROOT}/.swiftlint.yml" --baseline "${SRCROOT}/.swiftlint-baselines/app.json" "${SRCROOT}/record-catch"
   else
     echo "warning: SwiftLint not installed. Run 'brew install swiftlint' to lint on build."
   fi
   ```
4. Tick **"Based on dependency analysis"** off (no inputs/outputs) so it always runs.

Until that's done, `scripts/swiftlint.sh` (and CI, once wired up by the iOS DevOps engineer) is the
source of truth for lint results.
