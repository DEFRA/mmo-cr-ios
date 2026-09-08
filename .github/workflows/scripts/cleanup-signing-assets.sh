#!/usr/bin/env bash
set -euo pipefail

RUNNER_TEMP_DIR="${RUNNER_TEMP:-/tmp}"
KEYCHAIN_PATH="$RUNNER_TEMP_DIR/app-signing.keychain-db"
PROFILE_PATH="$HOME/Library/MobileDevice/Provisioning Profiles/dev.mobileprovision"

security delete-keychain "$KEYCHAIN_PATH" || true
rm -f "$PROFILE_PATH" || true
