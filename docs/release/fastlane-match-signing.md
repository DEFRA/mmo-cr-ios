# Fastlane Match signing — administrator runbook

This runbook covers every manual signing task for the three apps:

- adding the **Test** and **Prod** apps to the Match store (Part B);
- importing an existing certificate, which is how **Dev** was set up (Part C);
- repairing a stored key (Part D);
- certificate expiry (Part E);
- how CI uses the store (Part F).

Each step says **what** to do and **why**, so it can be followed without prior context.

Only a **signing administrator** does these tasks. CI never creates or changes signing assets: the release
pipeline runs `match` read-only.

Related documents:

- Decisions: [ADR-0011](../adr/0011-release-pipeline.md) (release pipeline) and
  [ADR-0014](../adr/0014-build-time-app-identity-configuration.md) (three app identities).
- Configuration: [fastlane/Matchfile](../../fastlane/Matchfile).
- Environments: [environments.md](environments.md).

> **Never commit or share signing material.** Certificates, private keys, `.p12` files, provisioning profiles,
> `MATCH_PASSWORD` and the deploy key never go into a repository, chat, ticket or log. Any file holding key
> material is created in a scratch directory outside the repository and deleted when the task ends. If a
> credential is exposed, follow DEFRA's
> [credential exposure process](https://defra.github.io/software-development-standards/processes/credential_exposure/).

## Contents

- [How signing works — read this first](#how-signing-works--read-this-first)
- [Part A — Prepare your workstation](#part-a--prepare-your-workstation)
- [Part B — Add a new app to the store (Test, Prod)](#part-b--add-a-new-app-to-the-store-test-prod)
- [Part C — Import an existing certificate and key](#part-c--import-an-existing-certificate-and-key)
- [Part D — Replace a stored private key](#part-d--replace-a-stored-private-key)
- [Part E — Certificate expiry and renewal](#part-e--certificate-expiry-and-renewal)
- [Part F — How CI uses the store](#part-f--how-ci-uses-the-store)
- [Troubleshooting](#troubleshooting)

---

## How signing works — read this first

**One certificate signs all three apps.** An Apple Distribution certificate belongs to the Apple Developer team,
not to an app. The team's certificate and private key are stored **once** and sign Dev, Test and Prod. Each app
has its **own App Store provisioning profile**, which ties that certificate to the app's bundle ID. Adding an app
therefore means adding a **profile**, not a certificate.

**What the store holds.** The private repository `DEFRA/mmo-cr-ios-signing-assets` (branch `main`) contains:

| Path | Content | Used by |
| --- | --- | --- |
| `certs/distribution/<CERT_ID>.cer` | Distribution certificate (public part) | All apps |
| `certs/distribution/<CERT_ID>.p12` | Its private key, as an **unencrypted PEM** file (Match keeps the `.p12` name) | All apps |
| `profiles/appstore/AppStore_<bundle-id>.mobileprovision` | App Store provisioning profile | One app |

`<CERT_ID>` is the certificate's ID in the Apple Developer portal. Every file is encrypted with OpenSSL using the
store passphrase `MATCH_PASSWORD`, so the repository never contains anything readable.

**Rules that are not obvious. Breaking them has caused failures.**

1. **The stored private key must be an unencrypted PEM RSA key, not a PKCS#12 file**, even though the store names
   it `.p12`. CI imports it with an empty password and cannot be given one, and macOS cannot reliably open an
   OpenSSL-made PKCS#12 that has an empty password. Match never checks the key when importing, so a wrong file only
   fails later, in CI (see [C5](#c5-extract-the-private-key-as-an-unencrypted-pem-file)).
2. **The `.cer` must be DER, not PEM.** Match compares it byte for byte with Apple's copy.
3. **`MATCH_PASSWORD` is one passphrase for the whole store.** It is kept in the team credential store and in the
   GitHub Environments. If it is lost, the store cannot be read and everything must be regenerated.
4. **Never let Match create a certificate.** If Match prints
   `Couldn't find a valid code signing identity for distribution... creating one for you now`, press **Ctrl+C**
   at once. Apple allows each team only a few distribution certificates, and this would use one up. It only
   happens when Match finds no certificate in the store: the wrong repository or branch, or an empty store.
5. **Never run `match nuke`, and never pass `--force` or `--renew_expired_certs`.** They revoke or replace assets
   that every app depends on.
6. **Use fastlane 2.240.0 or later.** The version is pinned in `Gemfile.lock`. Older versions cannot log in to
   Apple ([fastlane#30199](https://github.com/fastlane/fastlane/issues/30199)).

**Current state**

| App | Bundle ID | Profile in store | Procedure |
| --- | --- | --- | --- |
| Dev | `mmo.catchrecordingdev.ios` | Yes | Imported with [Part C](#part-c--import-an-existing-certificate-and-key) |
| Test | `mmo.catchrecordingtest.ios` | Not yet | [Part B](#part-b--add-a-new-app-to-the-store-test-prod) |
| Prod | `mmo.catchrecording.ios` | Not yet | [Part B](#part-b--add-a-new-app-to-the-store-test-prod) |

---

## Part A — Prepare your workstation

Do Part A once per administrator, plus A4 and A5 in **every new terminal** you use for Parts B–D.

Run every command from the root of **this** repository (`mmo-cr-ios`). Match reads `git_url`, `git_branch` and
`type` from [fastlane/Matchfile](../../fastlane/Matchfile) and clones the signing repository into a temporary
directory itself, so never clone or edit the signing repository by hand. The steps work on macOS and on
Linux/WSL; where the two differ, the step says so.

### A1. Check you have the access you need

| Access | Why |
| --- | --- |
| **Write** access to `DEFRA/mmo-cr-ios-signing-assets` | Match pushes the encrypted files using your own SSH key |
| Apple Developer team role **Admin**, or **App Manager** with *Access to Certificates, Identifiers & Profiles* | To register App IDs, create profiles, and let Match check the certificate |
| Read access to the team credential-store entries for `MATCH_PASSWORD` and the CI deploy key | To decrypt and re-encrypt the store, and to set up GitHub Environments |
| A trusted Apple device or phone number for two-factor codes | Every Apple ID login asks for a code |

### A2. Install the pinned tools

```bash
cd ~/path/to/mmo-cr-ios
git pull
bundle install
bundle exec fastlane --version   # must print 2.240.0 or later
```

*Why:* `bundle exec` runs the exact Fastlane version in `Gemfile.lock`, which is the same one CI uses. Older
versions fail Apple ID login with `Service key is empty`.

### A3. Give your machine SSH access to GitHub

Match pushes to the signing repository over SSH with **your personal key**. This is deliberately not the CI
deploy key, which is read-only and cannot push.

1. **Trust GitHub's host key.**

   ```bash
   mkdir -p ~/.ssh && chmod 700 ~/.ssh
   ssh-keyscan -t ed25519 github.com >> ~/.ssh/known_hosts
   ssh-keygen -lf ~/.ssh/known_hosts | grep -i github
   ```

   Compare the fingerprint printed with
   [GitHub's published SSH key fingerprints](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints).
   *Why:* without a known host key, `git` fails with `Host key verification failed.`. Checking the fingerprint
   proves you are talking to GitHub, not something pretending to be it.

2. **Create a personal SSH key** (skip if you already have one).

   ```bash
   ssh-keygen -t ed25519 -C "<your-name> signing admin" -f ~/.ssh/id_ed25519
   ```

   Set a passphrase when asked. *Why:* this key can write to the signing store. A passphrase stops a copied key
   file from being usable on its own.

3. **Register the public key.** **GitHub → Settings → SSH and GPG keys → New SSH key**, paste the contents of
   `~/.ssh/id_ed25519.pub`, then **Configure SSO → Authorize** it for `DEFRA`.
   *Why:* without SSO authorisation the key logs in to GitHub but is refused access to DEFRA repositories.

4. **Verify.**

   ```bash
   ssh -T git@github.com
   # Expected: Hi <username>! You've successfully authenticated, but GitHub does not provide shell access.
   ```

   `Permission denied (publickey)` means the key is missing, not loaded into the agent, or not SSO-authorised.

### A4. Make Match use your key, not the CI deploy key

```bash
unset MATCH_GIT_PRIVATE_KEY
```

*Why:* if this variable is set, Match uses the CI deploy key. That key is read-only, so the final push is rejected
after all the work is done.

### A5. Load the Match passphrase without leaving a trace

```bash
read -rsp 'Match passphrase: ' MATCH_PASSWORD && export MATCH_PASSWORD && echo
```

When prompted, paste the passphrase from the team credential store.

*Why:*

- Match needs the passphrase to decrypt and re-encrypt the store.
- `read -s` keeps it off the screen and out of shell history. Typing `export MATCH_PASSWORD='…'` would save it
  in `~/.bash_history`.
- Linux/WSL cannot cache the passphrase in a keychain, so load it in every new terminal.
- Always use the **existing** passphrase. A different one would encrypt new files with a key CI does not have.

**Only for a brand-new, empty store:** generate a passphrase with `openssl rand -base64 32`, save it in the team
credential store **first**, then load it as above.

---

## Part B — Add a new app to the store (Test, Prod)

Run Part B once for **Test**, then once for **Prod**. Finish [Part A](#part-a--prepare-your-workstation) first.

| Value | Test | Prod |
| --- | --- | --- |
| Bundle ID | `mmo.catchrecordingtest.ios` | `mmo.catchrecording.ios` |
| GitHub Environments that sign | `test`, `test-external` | `prod`, `prod-external` |
| App Store Connect app | Test app (TestFlight only) | Prod app (TestFlight and App Store) |

`prod-appstore` needs no signing secrets. App Store submission reuses the upload that `prod-external` signed.

### B1. Register the App ID

In the Apple Developer portal, go to **Certificates, Identifiers & Profiles → Identifiers → +**, choose
**App IDs**, then **App**, and fill in:

- **Description:** for example `MMO Catch Recording Test`.
- **Bundle ID:** **Explicit**, using the value from the table above.
- **Capabilities:** leave the defaults. The app declares no entitlements today. If it gains one (for example push
  notifications), enable the same capability on all three App IDs and re-create each app's profile.

*Why:*

- A profile is issued for exactly one App ID.
- Match does not create App IDs. It stops with `Couldn't find bundle identifier` if the ID is not registered.
- App Store distribution needs an explicit ID, not a wildcard.

### B2. Create the App Store Connect app record

In App Store Connect, go to **Apps → + → New App** and fill in:

- **Platform:** iOS.
- The app name and primary language.
- **Bundle ID:** the one from B1.
- **SKU:** for example `mmo-catch-recording-test`.

Restrict **User Access** to the release team.

*Why:* TestFlight uploads need an app record. The bundle ID is tied to the record permanently, so check it before
saving.

### B3. Confirm the stored certificate is valid

```bash
gh api repos/DEFRA/mmo-cr-ios-signing-assets/contents/certs/distribution --jq '.[].name'
```

Expect exactly one pair: `<CERT_ID>.cer` and `<CERT_ID>.p12`. Then, in the Developer portal under
**Certificates**, open the **Apple Distribution** certificate with that ID. Check it is active and that its
expiry date falls well after the planned release window.

*Why:*

- The new profile is bound to this certificate.
- An empty listing means Match would try to create a new certificate (rule 4). Stop and investigate.
- A certificate that expires soon means every app's profile needs replacing at that date
  ([Part E](#part-e--certificate-expiry-and-renewal)).
- With more than one pair, Match picks the last one listed. In that case, add `--certificate_id <CERT_ID>` to the
  B4 command to choose explicitly.

### B4. Let Match create the App Store profile

With A4 and A5 done in this terminal:

```bash
bundle exec fastlane match appstore \
  --app_identifier mmo.catchrecordingtest.ios \
  --team_id <APPLE_TEAM_ID> \
  --readonly false
```

For Prod, use `mmo.catchrecording.ios`. Sign in with your own Apple ID and two-factor code when asked.

*Why each part:*

- `appstore` selects the App Store distribution certificate and profile type that TestFlight and the App Store
  need.
- `--app_identifier` limits the run to the new app, so the Dev profile is left untouched.
- `--team_id` (the value of the `APPLE_TEAM_ID` secret) stops Match choosing the wrong team when your Apple ID
  belongs to several.
- `--readonly false` allows Match to create and push the profile. It is the default; stating it makes the intent
  explicit.

What happens, in order. Watch the output for each stage:

1. Match clones the store and decrypts it with `MATCH_PASSWORD`.
2. It logs in to Apple and checks that the App ID from B1 exists.
3. It finds the stored certificate and **reuses** it.
   - On Linux/WSL it prints `Skipping installation of certificate as it would not work on this operating system`.
     This is expected.
   - On macOS it installs the certificate into your login keychain.
4. It creates the profile `match AppStore <bundle-id>` in the Developer portal, bound to that certificate.
5. It encrypts the profile, commits it to the signing repository and pushes.
6. It prints a summary table and ends with `All required keys, certificates and provisioning profiles are installed`.

**Press Ctrl+C** if stage 3 says `Couldn't find a valid code signing identity ... creating one for you now`
(rule 4).

No private key is exported and no certificate is created; only the new profile is added. The profile is named
`match AppStore <bundle-id>`. Dev keeps the name of its imported profile. The release lane reads the profile name
from Match at run time, so both naming styles work.

### B5. Verify the store

```bash
gh api repos/DEFRA/mmo-cr-ios-signing-assets/commits --jq '.[0] | .sha[0:7] + "  " + .commit.author.date'
gh api repos/DEFRA/mmo-cr-ios-signing-assets/commits/<SHA> --jq '.files[] | .status + "  " + .filename'
```

Expect a new commit that adds `profiles/appstore/AppStore_<bundle-id>.mobileprovision`. The commit must **not**
change anything under `certs/`.

Then read the profile back the same way CI will: read-only, with no Apple login.

```bash
bundle exec fastlane match appstore --readonly true --app_identifier mmo.catchrecordingtest.ios
```

This must end with `All required keys, certificates and provisioning profiles are installed`.

*Why:*

- The commit check proves the right file was pushed and the shared certificate was not touched.
- The read-only run proves the file decrypts with the shared passphrase and sits where CI looks for it.
- On Linux/WSL this cannot test the private key, because there is no keychain. The first CI run tests it (B8).
- On macOS it installs the certificate and profile locally. Remove them afterwards if the machine is shared.

### B6. Add the app to the pipeline configuration (pull request)

Add the app in three places:

- [fastlane/Matchfile](../../fastlane/Matchfile): add the bundle ID to `app_identifier`.
- [fastlane/Fastfile](../../fastlane/Fastfile): add the app to `APPS`. This needs the app's scheme and build
  configuration from ADR-0014, which the iOS Developer adds.
- [environments.md](environments.md): mark the Match profile step as done for the app.

*Why:*

- The release lanes sign only the apps listed in `APPS`.
- The `certificates` lane checks every listed app, so an app must not be added before its profile exists.
- The Matchfile records which identities the store serves.

### B7. Give the app's GitHub Environments read-only access to the store

For **each** signing Environment of the app (Test: `test`, `test-external`; Prod: `prod`, `prod-external`), add
these two secrets:

| Secret | Value | Source |
| --- | --- | --- |
| `MATCH_PASSWORD` | The store passphrase | Team credential store |
| `MATCH_DEPLOY_KEY` | Private half of the read-only deploy key on the signing repository | Team credential store |

```bash
gh secret set MATCH_PASSWORD --repo DEFRA/mmo-cr-ios --env test
ssh-keygen -y -f /path/to/deploy-key > /dev/null && echo "OK: valid private key"
tr -d '\r' < /path/to/deploy-key | gh secret set MATCH_DEPLOY_KEY --repo DEFRA/mmo-cr-ios --env test
```

Repeat for the second Environment. `gh secret set` without `--body` prompts for the value, or reads it from
standard input, so the value never reaches shell history. Always set the deploy key from the file, never by
pasting it into the GitHub web page: `ssh-keygen -y` proves the file is a valid private key, and `tr -d '\r'`
removes Windows line endings. Either fault makes CI fail with `Error loading key ... invalid format`. Delete any
local copy of the deploy key afterwards. The other secrets, and the `MMO_API_BASE_URL` variable, are listed in
[environments.md](environments.md).

*Why:*

- GitHub hands an Environment's secrets only to jobs running in that Environment, and only after its approval
  gate.
- The deploy key is read-only, so even a compromised job can read the encrypted store but never change it.

**Optional, recommended for Prod: a separate deploy key.** This lets Prod's access be revoked without affecting
Dev and Test.

1. Generate a key pair in a scratch directory:
   `ssh-keygen -t ed25519 -N "" -C "mmo-cr-ios prod CI (read-only)" -f ./prod-deploy-key`.
2. In the signing repository, go to **Settings → Deploy keys → Add deploy key** and paste `prod-deploy-key.pub`.
   Leave **Allow write access** unticked.
3. Store the private half in the team credential store and in the `prod` and `prod-external` Environments.
4. Delete both files.

The key has no passphrase because CI cannot enter one. Its protection is that it is read-only and stored only as
a secret.

### B8. Prove it in CI

The first approved *iOS Release* run that builds the app is the end-to-end test. In the job log:

- the Match step must install the certificate and the profile;
- the release lane must **not** report `Signing certificate installed without its private key`.

*Why:* only a macOS runner imports the key into a keychain. This run is the first time the whole chain is
exercised: deploy key, passphrase, key format and profile. Do not upload a build purely to test signing; use the
app's first real, approved release.

### B9. Clean up

```bash
unset MATCH_PASSWORD
```

Part B leaves no key material on disk.

*Why:* the passphrase decrypts the key that signs every app. It should not stay in your shell after the task.

### Checklist

| Step | Test | Prod |
| --- | --- | --- |
| B1 App ID registered | [ ] | [ ] |
| B2 App Store Connect record created | [ ] | [ ] |
| B3 Stored certificate valid until after the release window | [ ] | [ ] |
| B4 Profile created and pushed by Match | [ ] | [ ] |
| B5 Store verified: new profile, `certs/` unchanged | [ ] | [ ] |
| B6 Matchfile / Fastfile / environments.md updated | [ ] | [ ] |
| B7 `MATCH_PASSWORD` + `MATCH_DEPLOY_KEY` set in both Environments | [ ] | [ ] |
| B8 First release run signed successfully | [ ] | [ ] |
| B9 Passphrase unset; scratch files deleted | [ ] | [ ] |

---

## Part C — Import an existing certificate and key

Use Part C in two cases:

- to put the team's certificate and key into an **empty** store (this is how Dev was set up);
- to replace a broken key ([Part D](#part-d--replace-a-stored-private-key)).

It is **not** needed to add an app: Part B does that with the certificate already in the store. Importing reuses
the team's existing certificate; creating a new one instead would use up one of the team's limited
distribution-certificate slots.

You need the certificate exported as a `.p12` (for example from Keychain Access on the Mac that created it), and
that file's export password.

### C1. Create a scratch directory outside the repository

```bash
mkdir -p ~/signing-import && chmod 700 ~/signing-import && cd ~/signing-import
# Copy the team's .p12 here as app-distribution.p12
```

*Why:* the next steps produce an unencrypted private key. Outside the repository it cannot be committed by
accident, and `chmod 700` keeps other users of the machine out.

### C2. Extract the certificate

```bash
openssl pkcs12 -in app-distribution.p12 -clcerts -nokeys -out cert.pem
```

Enter the `.p12` export password when prompted. If OpenSSL reports `digital envelope routines::unsupported`, the
file uses older encryption: add `-legacy`.

*Why:* Match needs the certificate as a separate file to identify it in the Developer portal.

### C3. Convert the certificate to DER (mandatory)

```bash
openssl x509 -in cert.pem -outform DER -out distribution.cer
```

*Why:* `openssl pkcs12` writes PEM text, but Match compares the file byte for byte with Apple's DER copy. A PEM
file never matches, and the import fails with a misleading message:
`the certificate contents did not match with any available on the Developer Portal`.

### C4. Check the certificate

```bash
file distribution.cer
# Expected: "Certificate, Version=3". "ASCII text" means it is still PEM: repeat C3.
openssl x509 -inform DER -in distribution.cer -noout -subject -enddate
```

The subject must name the MMO Apple Developer team, and the end date must be in the future.

*Why:* this catches a PEM file, the wrong team's certificate, or an expired certificate before anything is
written to the store.

### C5. Extract the private key as an unencrypted PEM file

This step is mandatory.

```bash
openssl pkcs12 -in app-distribution.p12 -nocerts -nodes -out key.pem    # add -legacy if "unsupported"
openssl rsa -in key.pem -out match-key.pem -traditional
head -1 match-key.pem   # Expected: -----BEGIN RSA PRIVATE KEY-----
[ "$(openssl rsa -in match-key.pem -noout -modulus)" = "$(openssl x509 -in cert.pem -noout -modulus)" ] \
  && echo "OK: key matches the certificate"
```

If `openssl version` shows **LibreSSL** (the macOS built-in), leave out `-traditional`: LibreSSL writes this format
by default.

*Why, line by line:*

1. `-nodes` extracts the private key **without** a password.
2. This rewrites the key as a clean, unencrypted RSA key in the traditional PEM format. That is exactly the format
   Fastlane stores when it creates a certificate itself. CI imports the key with `security import -P ""`. A PEM key
   has no password and no integrity check, so it imports every time. A PKCS#12 file does not work here, even with
   an empty password: macOS rejects OpenSSL-made empty-password PKCS#12 files with `MAC verification failed`.
3. This confirms the format.
4. This is the decisive check: it proves the key belongs to the certificate. `match import` does not inspect the
   file, and stores an exact copy of it. **If this check fails, do not import.**

`key.pem` and `match-key.pem` hold the private key **unencrypted**. C8 deletes them.

### C6. Import into the store

With A4 and A5 done in this terminal:

```bash
cd ~/path/to/mmo-cr-ios
bundle exec fastlane match import --team_id <APPLE_TEAM_ID>
```

Answer the prompts with **absolute paths**. A leading `~` is not expanded and gives
`Certificate does not exist at path:`.

| Prompt | Answer | Why |
| --- | --- | --- |
| Certificate (`.cer`) path | `/home/<user>/signing-import/distribution.cer` | The DER file from C3 |
| Private key (`.p12`) path | `/home/<user>/signing-import/match-key.pem` | The PEM key from C5. **Never** the original `.p12` |
| Provisioning profile path | Press **Enter** to skip | Profiles are created by Match (Part B), and existing ones stay as they are |
| Apple ID, password, two-factor code | Your own | Match looks up the certificate in the team to find its ID |

Match stores the files as `certs/distribution/<CERT_ID>.cer` and `.p12`, then encrypts, commits and pushes them.

*Why the files you give matter so much:*

- Match **does not ask for, open or check the private key**, and never asks for a password.
- Whatever file you give is exactly what CI receives.
- All apps share the certificate, so this key signs **every** app.

Do not use `--skip_certificate_matching`. It avoids the Apple login, but it also skips the check that the
certificate is valid and not revoked, and it stores the files under their local names instead of `<CERT_ID>`.

### C7. Verify the store

Run the two `gh api` commands and the read-only `match` command from [B5](#b5-verify-the-store), using the
Dev bundle ID.

- **Expected:** a new commit adding or updating `certs/distribution/<CERT_ID>.cer` and `.p12`, and nothing
  under `profiles/`.
- **If `<CERT_ID>` differs from the ID already in the store,** a different certificate was imported. Stop and
  check before anything is released.

*Why:* this proves what was pushed and that it decrypts with the shared passphrase. The key itself is tested by
C5 locally, and by the next CI run on macOS.

### C8. Clean up

```bash
cd ~ && rm -rf ~/signing-import && unset MATCH_PASSWORD
```

Also delete any other copy of the `.p12` you made for this task, for example in `Downloads`. Do not delete the
team's controlled copy.

*Why:* the scratch directory holds the private key unencrypted. The encrypted store is the only copy CI needs.

---

## Part D — Replace a stored private key

Use Part D when CI fails with `MAC verification failed during PKCS12 import`, or with the release lane's
`Signing certificate installed without its private key`. Either means the stored key file is not an unencrypted
PEM key: it has a password, or it is a PKCS#12 file.

Only the key file is replaced. The certificate, the profiles, the pipeline and the Matchfile stay as they are.
No new certificate is needed and nothing is revoked.

1. **[Part A](#part-a--prepare-your-workstation), A4 and A5.** Prepare the terminal.
2. **[C1–C5](#part-c--import-an-existing-certificate-and-key).** Rebuild `distribution.cer` and create
   `match-key.pem`. Match checks the certificate again to find its ID, so the `.cer` is needed too.
3. **[C6](#c6-import-into-the-store).** Give `distribution.cer` and `match-key.pem`, and press **Enter** at the
   profile prompt. The key is written to the same path, `certs/distribution/<CERT_ID>.p12`, so it overwrites the
   bad key in a new commit and every app picks it up.
4. **[C7](#c7-verify-the-store).** The new commit must change `certs/distribution/<CERT_ID>.p12` and keep the same
   `<CERT_ID>`.
5. **[C8](#c8-clean-up).** Delete the scratch files.
6. **Re-run the failed release.** The Match step must no longer report `MAC verification failed`.

---

## Part E — Certificate expiry and renewal

- A distribution certificate is valid for one year. Every app's App Store profile depends on it, so all three apps
  stop **signing new builds** when it expires.
- Apps already on TestFlight or the App Store are **not** affected by the expiry.
- Record the certificate's expiry date (Developer portal → **Certificates**) in the team calendar, with a reminder
  at least 30 days before.
- **The renewal procedure is not yet defined.** It is an open decision in the iOS DevOps design (certificate-expiry
  monitoring and emergency replacement). Until it is agreed, do not run `match nuke`, `--force` or
  `--renew_expired_certs`: they replace assets every app depends on.

---

## Part F — How CI uses the store

CI never imports or creates credentials. Every build and promotion Environment (`dev`, `test`,
`test-external`, `prod`, `prod-external` — see [environments.md](environments.md)) needs:

| Environment secret | Value |
| --- | --- |
| `MATCH_DEPLOY_KEY` | Private half of an SSH deploy key registered **read-only** on the signing repo |
| `MATCH_PASSWORD` | The store passphrase ([A5](#a5-load-the-match-passphrase-without-leaving-a-trace)) |

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
| `Service key is empty` / `Could not receive latest API key from App Store Connect` during Apple ID login | Fastlane older than 2.240.0 ([fastlane#30199](https://github.com/fastlane/fastlane/issues/30199)) | A2: `bundle install`, check the version |
| `Couldn't find bundle identifier '<bundle-id>'` | App ID not registered, or wrong team | B1; check `--team_id` |
| `Couldn't find a valid code signing identity ... creating one for you now` | Match found no certificate in the store | **Ctrl+C now** (rule 4). Check the Matchfile `git_url` / `git_branch` and B3 |
| `This certificate cannot be imported - the certificate contents did not match...` | The `.cer` is PEM, not DER | C3, then check with C4 |
| `Certificate does not exist at path:` | A `~` was used at a prompt | Use an absolute path |
| `Host key verification failed.` | `github.com` missing from `known_hosts` | A3 step 1 |
| `Permission denied (publickey)` | No personal SSH key, key not loaded, or not SSO-authorised for DEFRA | A3 steps 2–4 |
| Push rejected at the end of a run | `MATCH_GIT_PRIVATE_KEY` is set, so the read-only deploy key was used | A4 |
| `sh: 1: security: Permission denied` | `security` is macOS-only; Linux/WSL cannot cache the passphrase | Harmless. Load the passphrase with A5 |
| Asked for the Match passphrase on every run | Same cause as above | A5 |
| `digital envelope routines::unsupported` | The `.p12` uses legacy RC2 encryption | Add `-legacy` to the `openssl pkcs12` command |
| In CI: `MAC verification failed during PKCS12 import (wrong password?)`, then `No signing certificate "iOS Distribution" found` | The stored key file is a PKCS#12 file (with or without a password), not an unencrypted PEM key | [Part D](#part-d--replace-a-stored-private-key) |
| In CI: `Signing certificate installed without its private key` | Same as above, caught early by the release lane | [Part D](#part-d--replace-a-stored-private-key) |
| In CI: `No matching provisioning profiles found and cannot create a new one because you enabled readonly` | No profile in the store for that bundle ID | Part B for that app |
| In CI: `No code signing identity found and cannot create a new one because you enabled readonly` | No certificate in the store, or the wrong branch | B3; check the Matchfile |
| In CI: `Error loading key ".../match_deploy_key": invalid format`, then `Permission denied (publickey)` | The Environment's `MATCH_DEPLOY_KEY` is not a valid private key: Windows line endings, missing `BEGIN`/`END` lines, or the `.pub` key pasted | Check the file with `ssh-keygen -y -f <key>`, then re-set the secret from the file: `tr -d '\r' < <key> \| gh secret set MATCH_DEPLOY_KEY --repo DEFRA/mmo-cr-ios --env <env>` |
