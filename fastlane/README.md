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

### ios release_dev

```sh
[bundle exec] fastlane ios release_dev
```

Build, sign and upload the DEV app to its internal TestFlight group.

### ios distribute_dev_external

```sh
[bundle exec] fastlane ios distribute_dev_external
```

Distribute the latest uploaded DEV build to external tester groups on TestFlight.

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
