fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios build

```sh
[bundle exec] fastlane ios build
```

Compile the app and test bundle without running tests — the CI compile gate.

### ios test

```sh
[bundle exec] fastlane ios test
```

Build and run the unit tests with code coverage (used by CI). UI tests are excluded for now.

### ios certificates

```sh
[bundle exec] fastlane ios certificates
```

Sync every app's signing assets from the Match repo into the local keychain (read-only).

### ios build_internal

```sh
[bundle exec] fastlane ios build_internal
```

Compile the app ONCE with its internal backend URL, upload build N to internal TestFlight, keep the archive.

### ios promote_external

```sh
[bundle exec] fastlane ios promote_external
```

Re-package the kept archive with this Environment's backend URL as build N.1 and send it to external TestFlight. No recompile.

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
