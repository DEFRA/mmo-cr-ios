#!/usr/bin/env bash
# Encrypts/decrypts the compiled archive handed from the build job to the promotion job (ADR-0015).
# Public-repo artifacts are downloadable by any signed-in GitHub user, so the archive never leaves the run in clear.
set -euo pipefail
set +x

MODE="${1:?usage: release-archive.sh encrypt|decrypt}"
: "${ARCHIVE_ENCRYPTION_KEY:?ARCHIVE_ENCRYPTION_KEY is not set in this GitHub Environment}"

RELEASE_DIR="build/release"
ENCRYPTED="build/release-archive.tar.gz.enc"

# Prefer Homebrew OpenSSL 3; the system LibreSSL may lack -pbkdf2.
OPENSSL="openssl"
if command -v brew >/dev/null 2>&1 && [[ -x "$(brew --prefix openssl@3)/bin/openssl" ]]; then
  OPENSSL="$(brew --prefix openssl@3)/bin/openssl"
fi
CIPHER=(enc -aes-256-cbc -pbkdf2 -iter 200000 -pass env:ARCHIVE_ENCRYPTION_KEY)

case "$MODE" in
  encrypt)
    tar -C "$RELEASE_DIR" -czf - record-catch.xcarchive mach-o-uuids.json \
      | "$OPENSSL" "${CIPHER[@]}" -salt -out "$ENCRYPTED"
    ;;
  decrypt)
    mkdir -p "$RELEASE_DIR"
    "$OPENSSL" "${CIPHER[@]}" -d -in "$ENCRYPTED" | tar -C "$RELEASE_DIR" -xzf -
    ;;
  *)
    echo "::error::Unknown mode '$MODE' (expected encrypt|decrypt)" >&2
    exit 1
    ;;
esac
