# Fastlane Match — importing existing signing assets

How the app's existing Apple **distribution certificate** and **App Store provisioning profile** were
imported into the Fastlane Match store, and how to repeat the process.

This is a **one-off task performed by a signing administrator**. CI never does any of this: the release
pipeline only ever runs `match` in read-only mode. See
[ADR 0011 — Release pipeline](../adr/0011-release-pipeline.md) for the decision and rationale, and
[fastlane/Matchfile](../../fastlane/Matchfile) for the configuration.

> **Never commit certificates, private keys, `.p12` files or provisioning profiles to this repository.**
> Everything below happens in a scratch directory outside the repo and is deleted afterwards. If a
> credential is ever exposed, follow DEFRA's
> [credential exposure process](https://defra.github.io/software-development-standards/processes/credential_exposure/).

---

## What Match stores, and where

Match keeps three encrypted artefacts per app identifier in the **private** repository
[DEFRA/mmo-cr-ios-signing-assets](https://github.com/DEFRA/mmo-cr-ios-signing-assets):

| Artefact | File | Purpose |
| --- | --- | --- |
| Certificate | `.cer` | The public Apple Distribution certificate |
| Private key | `.p12` | The matching private key |
| Provisioning profile | `.mobileprovision` | Ties the certificate to the bundle identifier |

Each file is encrypted with OpenSSL using a passphrase (`MATCH_PASSWORD`) that is **never** stored in the
repository. Losing that passphrase makes the store undecryptable and forces a `match nuke` and full
regeneration, so it lives in the team credential store.

`fastlane match import` is used instead of `fastlane match appstore` so the team's **existing** certificate
is reused. Generating a new one would consume one of Apple's three distribution-certificate slots and
invalidate builds signed with the old one.

---

## Prerequisites

- Write access to `DEFRA/mmo-cr-ios-signing-assets`.
- An Apple Developer account with at least **App Manager** on the Marine Management Organisation team
  (needed only to validate the certificate against the Developer Portal during import).
- The existing `.p12`, its export password, and the `.mobileprovision` file.
- Ruby and the pinned Fastlane from this repo (`bundle install`).

All commands are run **from the root of this repository (`mmo-cr-ios`)**, not from the signing-assets
repo. Match clones the signing repo into a temporary directory itself — you never clone it manually.
Settings such as `git_url`, `git_branch`, `type` and `app_identifier` are read automatically from
[fastlane/Matchfile](../../fastlane/Matchfile), so they do not need to be passed on the command line.

---

## Step 1 — SSH access to GitHub from the development machine

Match pushes to the signing repo over SSH, so the machine needs a **personal** SSH key with *write*
access. This is deliberately **not** the CI deploy key: that key is registered read-only and cannot push.

Make sure `MATCH_GIT_PRIVATE_KEY` is unset in your shell, or Match will use the read-only deploy key and
the final push will be rejected:

```bash
unset MATCH_GIT_PRIVATE_KEY
```

### 1a. Trust GitHub's host key

Without this, `git clone` fails with `Host key verification failed.`

```bash
mkdir -p ~/.ssh
ssh-keyscan -t ed25519,rsa github.com >> ~/.ssh/known_hosts
```

### 1b. Create a personal SSH key (skip if you already have one)

```bash
ssh-keygen -t ed25519 -C "<your-name>@defra-dev-machine" -f ~/.ssh/id_ed25519 -N ""
cat ~/.ssh/id_ed25519.pub
```

### 1c. Register the public key on your GitHub account

**GitHub → Settings → SSH and GPG keys → New SSH key**, then paste the public key.

If the DEFRA organisation enforces SAML SSO, click **Configure SSO** next to the new key and
**Authorize** it for `DEFRA`. Without this the key authenticates but is denied access to DEFRA repos.

### 1d. Verify

```bash
ssh -T git@github.com
# Expected: Hi <username>! You've successfully authenticated, but GitHub does not provide shell access.
```

`Permission denied (publickey)` means the key is missing, not loaded, or not SSO-authorised.

---

## Step 2 — Prepare the certificate files

Work in a scratch directory outside the repository:

```bash
mkdir -p ~/signing-import && cd ~/signing-import
# copy app-distribution.p12 and the .mobileprovision here
```

### 2a. Extract the certificate from the `.p12`

If you only have the `.p12`, extract the public certificate from it. You will be prompted for the
`.p12` export password (the value previously held in the retired `P12_PASSWORD` secret):

```bash
openssl pkcs12 -in app-distribution.p12 -clcerts -nokeys -out cert.pem
```

If OpenSSL reports `digital envelope routines::unsupported`, the `.p12` uses legacy RC2 encryption from
an older macOS; add the `-legacy` flag.

### 2b. Convert the certificate to DER — this step is mandatory

**`openssl pkcs12` outputs PEM (base64 text with a `Bag Attributes` preamble). Match requires DER.**

Match validates a certificate by base64-encoding its raw bytes and comparing them byte-for-byte with the
certificates downloaded from the Apple Developer Portal, which are DER. A PEM file can never match, and
the import fails with a misleading error:

```
[!] This certificate cannot be imported - the certificate contents did not match with any available on the Developer Portal
```

That message suggests an account or permissions problem; in practice it is almost always this format
mismatch. Convert to DER:

```bash
openssl x509 -in cert.pem -outform DER -out distribution.cer
```

### 2c. Verify before importing

```bash
file distribution.cer
# Expected: distribution.cer: Certificate, Version=3
# Wrong:    distribution.cer: ASCII text     <- still PEM, go back to 2b

openssl x509 -inform DER -in distribution.cer -noout -subject -dates
```

Confirm the subject names the correct team, and that the certificate has not expired.

Optionally, check the provisioning profile's bundle identifier, team and expiry match the certificate:

```bash
openssl smime -inform der -verify -noverify -in *.mobileprovision 2>/dev/null \
  | grep -A2 -E '<key>(Name|application-identifier|TeamIdentifier|ExpirationDate)</key>'
```

The `application-identifier` must end in `mmo.catchrecordingdev.ios`.

---

## Step 3 — Import into the Match store

Generate a strong passphrase (once only, for a brand-new store) and record it in the team credential
store before running anything:

```bash
openssl rand -base64 32
```

Then run the import from the repository root:

```bash
cd /path/to/mmo-cr-ios

export MATCH_PASSWORD='<the passphrase>'

bundle exec fastlane match import --team_id <APPLE_TEAM_ID>
```

`--team_id` is optional but recommended: without it Match logs in with no team context and, if your Apple
ID belongs to several teams, may query the wrong one. The value is the same as the `APPLE_TEAM_ID`
secret.

Match prompts for three paths. **Use absolute paths — a leading `~` is not expanded** and produces
`Certificate does not exist at path:`.

| Prompt | File |
| --- | --- |
| Certificate (`.cer`) path | `/home/<user>/signing-import/distribution.cer` (the **DER** file from 2b) |
| Private key (`.p12`) path | `/home/<user>/signing-import/app-distribution.p12` |
| Provisioning profile path | `/home/<user>/signing-import/<profile>.mobileprovision` |

You will also be asked for:

- the `.p12` export password;
- the Match passphrase, if `MATCH_PASSWORD` was not exported — on a **new, empty** store you are asked to
  set and confirm it, and that value becomes the permanent repository passphrase;
- your Apple ID, password and 2FA code, so Match can validate the certificate against the Developer
  Portal.

Match then encrypts each file, commits them to the signing repo and pushes.

### Skipping Developer Portal validation

`--skip_certificate_matching true` bypasses the Apple login entirely. Use it only when there is genuinely
no portal access — it also skips the check that the certificate is valid and unrevoked, so a bad
certificate can be published to the store unnoticed. Prefer fixing the DER conversion in step 2b.

---

## Step 4 — Verify the store

```bash
git clone git@github.com:DEFRA/mmo-cr-ios-signing-assets.git /tmp/match-verify
find /tmp/match-verify -path '*/.git' -prune -o -type f -print
rm -rf /tmp/match-verify
```

Expect encrypted files under `certs/distribution/` and `profiles/appstore/`, plus a generated
`README.md`. The file contents must be unreadable ciphertext.

Then confirm the **read-only CI path** works, using the deploy key exactly as the runner does:

```bash
cd /path/to/mmo-cr-ios
MATCH_GIT_PRIVATE_KEY=~/.ssh/mmo_cr_match_deploy_key \
MATCH_PASSWORD='<the passphrase>' \
bundle exec fastlane certificates
```

This runs `match(readonly: true)` and must succeed without contacting the Developer Portal.

---

## Step 5 — Clean up

The scratch directory holds the **private signing key in plaintext**. Remove it as soon as the import is
verified:

```bash
rm -rf ~/signing-import
```

Also remove any manual clone of the signing repository. Confirm nothing was staged or committed into this
repository.

---

## CI configuration

CI never imports or creates credentials. The release workflow only needs:

| `dev` Environment secret | Value |
| --- | --- |
| `MATCH_DEPLOY_KEY` | Private half of an SSH deploy key registered **read-only** on the signing repo |
| `MATCH_PASSWORD` | The passphrase from step 3 |

A **dedicated** deploy key is required: GitHub rejects the same key on two repositories, and
`actions/checkout` authenticates with `GITHUB_TOKEN` rather than SSH, so there is no conflict.

At run time, [.github/workflows/scripts/setup-match-ssh-key.sh](../../.github/workflows/scripts/setup-match-ssh-key.sh)
writes the key to `RUNNER_TEMP` with `0600`, pins GitHub's published host key, and exports
`MATCH_GIT_PRIVATE_KEY`. The Fastfile then calls `setup_ci` (isolated temporary keychain) followed by
`match(readonly: true)`, and
[.github/workflows/scripts/cleanup-signing-assets.sh](../../.github/workflows/scripts/cleanup-signing-assets.sh)
destroys both in an `always()` step.

---

## Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| `This certificate cannot be imported - the certificate contents did not match...` | The `.cer` is PEM, not DER | Step 2b; verify with `file` |
| `Certificate does not exist at path:` | A `~` was used in a prompt | Use an absolute path |
| `Host key verification failed.` | `github.com` missing from `known_hosts` | Step 1a |
| `Permission denied (publickey)` | No personal SSH key, or not SSO-authorised for DEFRA | Steps 1b–1c |
| Push rejected at the end of the import | `MATCH_GIT_PRIVATE_KEY` is set, forcing the read-only deploy key | `unset MATCH_GIT_PRIVATE_KEY` |
| `sh: 1: security: Permission denied` | `security` is macOS-only; on Linux/WSL the passphrase cannot be cached in a keychain | Harmless — always `export MATCH_PASSWORD` |
| Prompted for the Match passphrase on every run | Same cause as above | `export MATCH_PASSWORD` |
| `digital envelope routines::unsupported` | `.p12` uses legacy RC2 encryption | Add `-legacy` to the `openssl pkcs12` command |
