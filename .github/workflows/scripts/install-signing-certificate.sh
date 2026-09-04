#!/usr/bin/env bash
set -euo pipefail
# Ensure command tracing is disabled so passwords and decoded keys are not leaked in CI logs
set +x

RUNNER_TEMP_DIR="${RUNNER_TEMP:-/tmp}"
CERT_PATH="$RUNNER_TEMP_DIR/dev_signing.p12"
PROFILE_PATH="$RUNNER_TEMP_DIR/dev.mobileprovision"
KEYCHAIN_PATH="$RUNNER_TEMP_DIR/app-signing.keychain-db"

# Decode the certificate and provisioning profile from secrets without printing output.
printf '%s' "$BUILD_CERTIFICATE_BASE64" | base64 --decode -o "$CERT_PATH"
printf '%s' "$BUILD_PROVISION_PROFILE_BASE64" | base64 --decode -o "$PROFILE_PATH"

# Create and unlock a temporary keychain, then import the signing certificate.
security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH" >/dev/null 2>&1
security set-keychain-settings -lut 21600 "$KEYCHAIN_PATH" >/dev/null 2>&1
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH" >/dev/null 2>&1
security import "$CERT_PATH" -P "$P12_PASSWORD" -A -t cert -f pkcs12 -k "$KEYCHAIN_PATH" >/dev/null 2>&1
security set-key-partition-list -S apple-tool:,apple: -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH" >/dev/null 2>&1
security list-keychain -d user -s "$KEYCHAIN_PATH" login.keychain-db >/dev/null 2>&1

# Install the provisioning profile where Xcode looks for it.
mkdir -p "$HOME/Library/MobileDevice/Provisioning Profiles"
cp "$PROFILE_PATH" "$HOME/Library/MobileDevice/Provisioning Profiles/"
