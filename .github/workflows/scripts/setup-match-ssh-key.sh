#!/usr/bin/env bash
set -euo pipefail
# Ensure command tracing is disabled so the private key is never echoed into CI logs.
set +x

RUNNER_TEMP_DIR="${RUNNER_TEMP:-/tmp}"
KEY_PATH="$RUNNER_TEMP_DIR/match_deploy_key"

umask 077
printf '%s\n' "${MATCH_DEPLOY_KEY%$'\n'}" > "$KEY_PATH"
chmod 600 "$KEY_PATH"

mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

# Pin GitHub's published SSH host key rather than trusting ssh-keyscan on first use.
# https://docs.github.com/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints
cat >> "$HOME/.ssh/known_hosts" <<'EOF'
github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl
EOF
chmod 600 "$HOME/.ssh/known_hosts"

# Consumed by fastlane match (git_private_key) in the subsequent build step.
echo "MATCH_GIT_PRIVATE_KEY=$KEY_PATH" >> "$GITHUB_ENV"
