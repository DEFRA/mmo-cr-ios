---
description: "Security standards for the MMO Catch Recording iOS app: DEFRA Secure by Design, OWASP MASVS, Keychain, ATS/TLS, data-at-rest protection, authentication, secrets management, error logging. Use when handling data, networking, auth, storage, or reviewing security."
applyTo: **/*.swift, **/Info.plist, **/*.entitlements, **/*.xcconfig
---

# Security standards

Precedence: DEFRA security > GDS > OWASP MASVS/Apple. DEFRA services must follow
**[Secure by Design](https://www.security.gov.uk/guidance/secure-by-design/principles/)** principles and
DEFRA [security standards](https://defra.github.io/software-development-standards/standards/security_standards/).
Design the app's complete security profile **before** finalising scope/MVP. For access to non-public
DEFRA systems, the security profile must be agreed with the **Cloud Mobile Services** team.

Mobile devices are easily lost/stolen and often use public networks — treat the device as potentially
insecure.

## Encryption in transit (mandatory)

- **All traffic must be encrypted** (HTTPS/TLS). Never use plain HTTP.
- Keep **App Transport Security** enabled; do **not** add `NSAllowsArbitraryLoads`. Justify and scope any
  exception and raise it through governance.
- Consider certificate pinning for sensitive endpoints. For internal DEFRA back-ends, per-app VPN (via
  MDM) may be required — confirm with Cloud Mobile Services.

## Data at rest

- Store secrets/tokens/keys in the **Keychain** (with appropriate accessibility, e.g.
  `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`). Never in `UserDefaults`, plists or source.
- Protect sensitive local/offline data: enable Data Protection (`NSFileProtectionComplete` where
  feasible) and/or encrypt the local store. Rely on the app sandbox; minimise data retained on device.
- Do not log or cache sensitive personal data. Apply data minimisation.

## Authentication

- Prefer platform-secure auth (OAuth 2.0/OIDC with PKCE, ASWebAuthenticationSession). Store tokens in
  Keychain; refresh securely; support biometric unlock (Face ID/Touch ID) where appropriate with a
  passcode fallback.
- For known external users, an "by invitation" pattern via a recorded email/address may be sufficient —
  confirm identity-assurance requirements with security. Do not build bespoke identity proofing without advice.

## Secrets management

- **Never commit** API keys, certificates, provisioning profiles, `.p8`/`.p12`, or passwords. Use CI
  encrypted secrets and `.gitignore`. If a secret leaks, follow the DEFRA
  [credential exposure](https://defra.github.io/software-development-standards/processes/credential_exposure/) process immediately.
- Enable **GitHub Advanced Security** (secret scanning, Dependabot) and DEFRA SonarCloud.

## Error logging & diagnostics (DEFRA mobile requirement)

- The app **must log errors** and let a user share diagnostics for support (e.g. exportable logs or, at
  minimum, a screenshot-able error). Support a configurable **debug** log level.
- Use structured logging (`OSLog`/`Logger`) with appropriate privacy redaction (`privacy: .private` for
  sensitive values). Never log secrets or personal data in plaintext.

## Secure coding (OWASP MASVS-aligned)

- Validate and sanitise all input at boundaries; never trust remote or on-device data blindly.
- Avoid insecure APIs; keep dependencies patched (SPM, pinned, vetted).
- No hard-coded credentials or debug backdoors in release builds. Strip verbose logging from release.
- Follow the platform's least-privilege model for permissions (location, camera, etc.); request only
  what's needed and explain why in usage descriptions.
