# Dev handoff — MSAL Native Auth silent-token keychain-group mismatch (ADR-0022 addendum, ADR-0025)

- **Area:** `record-catch/Core/Security/Auth/MSALNativeAuthenticator.swift`
- **Status:** Fixed and confirmed working against the dev Entra tenant (real `access_as_user` token
  retrieved and decoded — `aud` = Catch Recording Service app ID, `scp` = `access_as_user`).
- **Related:** [ADR-0022](../adr/0022-entra-external-id-native-authentication.md),
  [ADR-0025](../adr/0025-catch-recording-service-connector.md),
  [2026-11-entra-sign-in-native-auth.md](2026-11-entra-sign-in-native-auth.md).

## Symptom

Every call to `accessToken()` (and, less obviously, every *silent* call inside `restoreSession()`)
failed. Across different test runs this showed up as **two different-looking MSAL errors**, which
delayed diagnosis because they looked like unrelated problems:

1. `MSIDKeychainErrorDomain` — `"Failed to get items from keychain."` (intermittent).
2. `MSALNativeAuthError` — `"No token matching arguments found in the cache, user interaction is
   required"` (consistent, once the app had a `keychain-access-groups` entitlement at all).

Red herrings chased before the real cause was found (recorded here so nobody repeats the work):
missing Entra API permission, missing admin consent, a scope-string mismatch, a sign-in-time scope
omission (this one **was** real and worth fixing, see §3), and a "cold-start" keychain race
(disproved — a retry-with-delay band-aid did **not** reliably fix it).

## Root cause

`MSALNativeAuthenticator.init()` used to set:

```swift
if let bundleID = Bundle.main.bundleIdentifier {
    config.cacheConfig.keychainSharingGroup = bundleID
}
```

on the config used to build `self.application`, following MSAL's own "Configure keychain" guidance
for avoiding the shared `com.microsoft.adalcache` keychain-access-group entitlement. This override
**is** honoured by that one `MSALPublicClientApplication` instance (`MSALPublicClientApplication.m`
builds its `MSIDKeychainTokenCache` with `initWithGroup:config.cacheConfig.keychainSharingGroup`).

But every **silent** token call — `restoreSession()` and `accessToken()`'s underlying
`userAccount.getAccessToken(parameters:)` — goes through MSAL Native Auth's internal
`getAccessTokenInternal` (`MSALNativeAuthUserAccountResult+Internal.swift`), which **constructs a
brand-new `MSALNativeAuthPublicClientApplicationConfig` from scratch for every call** and never
copies `cacheConfig` across. That fresh config's `cacheConfig` lazily defaults to the SDK's own
static default group (`MSIDKeychainTokenCache.defaultKeychainGroup`, i.e. `com.microsoft.adalcache`
on iOS) — **not** our override.

Net effect: sign-in wrote the refresh token under `TeamID.<bundle id>`; every silent request then
looked for it under `TeamID.com.microsoft.adalcache` — a different keychain access group entirely.
`MSIDSilentTokenRequest.m`'s `redeemAccessTokenWith:` hits `if (!refreshToken)` and raises
`MSIDErrorInteractionRequired` with the exact message above, **without ever making a network call**.
This is why checking Entra's app registration (permissions/consent/scope string) all checked out
fine — the bug was entirely local, inside the SDK's own config plumbing, never server-side.

The earlier, intermittent `"Failed to get items from keychain."` was the same mismatch manifesting
differently: Simulator inconsistently enforces `errSecMissingEntitlement` for a keychain access
group the app isn't entitled for, depending on simulator/keychain state.

Traced by reading the local MSAL 2.17.0 SPM checkout directly — see
`MSAL/src/MSALPublicClientApplication.m` (`initWithGroup:`) and
`MSAL/IdentityCore/IdentityCore/src/requests/MSIDSilentTokenRequest.m` (`redeemAccessTokenWith:`).

## Fix

1. **Removed** the `cacheConfig.keychainSharingGroup` override in `MSALNativeAuthenticator.init()`.
   Every code path — the top-level instance and MSAL's internally-reconstructed ones — now
   consistently resolves to the SDK's real default group.
2. **Added the matching entitlement** in `record-catch.entitlements`:
   ```xml
   <key>keychain-access-groups</key>
   <array>
       <string>$(AppIdentifierPrefix)$(PRODUCT_BUNDLE_IDENTIFIER)</string>
       <string>$(AppIdentifierPrefix)com.microsoft.adalcache</string>
   </array>
   ```
   (The first entry is unrelated — this app's own private keychain items, e.g. ADR-0009's
   `KeychainStoring`. The second is MSAL's real default group, now required since we no longer
   opt out of it.)

## §3 — a second, genuinely real fix found along the way

Independently of the keychain-group bug, `signIn(email:password:)` never requested
`catchRecordAPIScope` as part of the sign-in token request — only MSAL's implicit
openid/profile/offline_access scopes were requested. Even with the keychain-group bug fixed, a
fresh sign-in would still have no token/refresh-token grant covering the Catch Recording Service
scope. Fixed by setting `parameters.scopes = [catchRecordAPIScope]` on the
`MSALNativeAuthSignInParameters` before calling `application.signIn(...)`. This requires the scope
to already be an admin-consented API permission on the client app's Entra registration (confirmed
present for dev — ADR-0025).

## Required follow-up for anyone hitting this again

A **fresh sign-in is required** after this fix — an already-signed-in session's refresh token was
written under the wrong keychain group and/or without the right scope, and will never silently pick
up either fix. Sign out (Settings → Sign out), then sign in again.

## Lesson for future MSAL work

**Do not override `MSALCacheConfig.keychainSharingGroup`** on a `MSALNativeAuthPublicClientApplicationConfig`
used for MSAL **Native Authentication** (as opposed to classic interactive/broker MSAL). The override
is not respected by Native Auth's own silent-token code path in MSAL 2.17.0, and will silently break
every `getAccessToken(parameters:)` call. If this needs revisiting on an MSAL upgrade, check whether
a newer SDK version threads `cacheConfig` through `getAccessTokenInternal` before reintroducing an
override.
