# PR: Catch-location map — port-framing tests (QA / UI-test only)

**Branch:** `UItestautomation` → `main`
**Related ticket:** Display Departure Port and Nearest ICES Statistical Rectangles

---

## Summary

Adds **tests only** for the catch-location map: unit tests that the departure port (and its
coordinate) is surfaced from the draft for `PortMapCamera` framing, plus an in-app UI smoke test
that the map screen opens.

This PR contains **no app / production code changes**. The `-uiTestCatchLocation` launch seam that
the UI test relies on is delivered separately (see *Dependency* below), so QA and app changes stay
in distinct PRs.

## What changed

| File | Change |
|------|--------|
| `record-catchTests/.../CatchLocationViewModelTests.swift` | 2 new unit tests: departure port + coordinate surfaced from the draft; nil when absent |
| `record-catchUITests/CatchLocationUITests.swift` | New UI smoke test: seam boots to the map without sign-in |
| `docs/test-reports/catch-location-departure-port.md` | Test report + requirement traceability + open BA/dev queries |
| `docs/dev-handoff/catch-location-seam.patch` | The reverted app-target launch seam, preserved for the separate dev PR |
| `.gitignore` | Ignore `build/` and `*.xcresult` (local test artifacts) |

> **Not in this PR (reverted):** `record-catch/App/LaunchArguments.swift` and
> `record-catch/App/UITestRootView.swift`. These app-target seam changes were moved out so this
> branch is tests-only; they are captured in `docs/dev-handoff/catch-location-seam.patch`.

## ⚠️ Dependency — this PR must be stacked on the dev seam PR

`CatchLocationUITests` boots the map via the `-uiTestCatchLocation` launch argument, which is
implemented in the app target. XCUITest can only inject state via launch arguments, so that seam
**cannot** live in the test target.

- The **unit tests** are self-contained and pass on this branch alone. ✅
- The **UI test** will only pass once the dev seam PR (from `catch-location-seam.patch`) is merged
  and this branch is rebased on it. ⚠️

Apply the seam on a dev branch with:

```bash
git apply docs/dev-handoff/catch-location-seam.patch
```

## Testing

```bash
# Unit tests (pass on this branch as-is)
xcodebuild test -scheme record-catch \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:record-catchTests/CatchLocationViewModelTests

# UI test (requires the dev seam PR merged / rebased in)
xcodebuild test -scheme record-catch \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:record-catchUITests/CatchLocationUITests
```

## Requirement coverage (honest status)

| Req | Status |
|-----|--------|
| FR1 — centre map on departure port | ✅ Covered (unit) |
| AC1 — departure port visible | ✅ Covered (unit) |
| FR2 — 9 nearest rectangles by default | 🟡 Covered *assuming* "rectangle" = selectable subrectangle |
| FR3 — same behaviour for all ports | 🟡 Partial (uniform code path, no multi-port loop) |
| FR4 — minimum permitted zoom | ⚠️ Not asserted (blocked on BA decision) |
| Fallback when no port location | ✅ Covered (unit) |

## ⚠️ Open questions before this ticket is "fully verified"

**BA / Product Owner:**
1. "9 ICES Statistical Rectangles" — the 9 selectable **subrectangles** (built) or 9 **parent
   rectangles** (literal)?
2. FR4 "minimum permitted zoom" — open at exactly 9 cells, or the widest permitted zoom?
3. AC1 "no rectangles outside the default view" — exactly 9, or "roughly 9, centred"?

**Dev informs, BA confirms:**
4. "Centre on port" vs the deliberate sea-bias (keeps the coastal port visible) — acceptable?
5. Test layer: exact centring/cell-count is unit-testable (`PortMapCamera`), not reliably
   XCUITest-assertable.

Full detail: `docs/test-reports/catch-location-departure-port.md`.

## Checklist

- [x] Tests-only PR — no app / production code changes
- [x] Unit tests added and passing on this branch
- [x] App-target seam reverted and preserved for a separate dev PR
- [x] Build artifacts git-ignored
- [ ] Stack on / rebase after the dev seam PR so `CatchLocationUITests` passes in CI
- [ ] BA/dev queries resolved → then add FR4 test + exact-cell-count assertion
