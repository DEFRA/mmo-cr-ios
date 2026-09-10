#!/usr/bin/env bash
set -euo pipefail

RUNNER_TEMP_DIR="${RUNNER_TEMP:-/tmp}"
KEY_PATH="$RUNNER_TEMP_DIR/match_deploy_key"

rm -f "$KEY_PATH" || true

# Temporary keychain created by fastlane's setup_ci action, holding the Match signing identity.
security delete-keychain "fastlane_tmp_keychain" >/dev/null 2>&1 || true
security list-keychains -d user -s login.keychain-db >/dev/null 2>&1 || true
