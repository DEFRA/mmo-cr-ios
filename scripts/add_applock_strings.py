#!/usr/bin/env python3
"""Add offline biometric local re-entry ("app lock") localisation keys to
Localizable.xcstrings (see docs/adr/0009-offline-biometric-local-reentry.md and
docs/design-specs/manage-account.md deviation #3).

Idempotent: skips any key that already exists. Welsh values are placeholders
pending translation and are marked `needs_review` (never a `[CY-TODO]` prefix
in rendered copy).
"""
import json
import pathlib
import sys

CATALOG = pathlib.Path(__file__).resolve().parents[1] / "record-catch" / "Resources" / "Localizable.xcstrings"

# key -> (comment, english, welsh_placeholder)
NEW_KEYS = {
    "appLock.error.authenticationFailed": (
        "Perceivable (text+icon) failure message on the app-lock screen when a biometric "
        "attempt fails but retrying may help (ADR-0009).",
        "We could not verify it's you. Try again, or sign in with your password instead.",
        "Ni allem wirio mai chi ydyw. Rhowch gynnig arall arni, neu mewngofnodwch gyda'ch "
        "cyfrinair yn lle hynny.",
    ),
    "appLock.error.biometryLockedOut": (
        "Shown briefly before falling back to the sign-in form after too many failed "
        "biometric attempts locked biometrics on this device (ADR-0009).",
        "Face ID/Touch ID is temporarily locked on this device. Sign in with your password.",
        "Mae Face ID/Touch ID wedi'i gloi dros dro ar y ddyfais hon. Mewngofnodwch gyda'ch "
        "cyfrinair.",
    ),
    "appLock.error.biometryUnavailable": (
        "Shown briefly before falling back to the sign-in form when biometrics are not "
        "available/enrolled on this device (ADR-0009).",
        "Face ID/Touch ID is not available on this device. Sign in with your password.",
        "Nid yw Face ID/Touch ID ar gael ar y ddyfais hon. Mewngofnodwch gyda'ch cyfrinair.",
    ),
    "appLock.error.cancelled": (
        "Shown on the app-lock screen after the user cancels a biometric prompt (ADR-0009).",
        "Sign-in was cancelled. Try again, or sign in with your password instead.",
        "Cafodd mewngofnodi ei ganslo. Rhowch gynnig arall arni, neu mewngofnodwch gyda'ch "
        "cyfrinair yn lle hynny.",
    ),
    "appLock.faceID.scanHint": (
        "Hint shown above the unlock button only on Face ID devices, since Face ID scans "
        "immediately with no explicit start step (Apple HIG; ADR-0009).",
        "Face ID will scan automatically",
        "Bydd Face ID yn sganio'n awtomatig",
    ),
    "appLock.fallback.link": (
        "Always-visible manual fallback link on the app-lock screen, so the user is never "
        "dead-ended by a failed/unavailable biometric check (ADR-0009).",
        "Sign in with your password instead",
        "Mewngofnodwch gyda'ch cyfrinair yn lle hynny",
    ),
    "appLock.heading": (
        "Heading on the offline biometric local re-entry (\"app lock\") screen (ADR-0009).",
        "Welcome back",
        "Croeso'n ôl",
    ),
    "appLock.unlock.faceID": (
        "Primary button title on the app-lock screen when Face ID is available (ADR-0009).",
        "Unlock with Face ID",
        "Datgloi gyda Face ID",
    ),
    "appLock.unlock.generic": (
        "Primary button title on the app-lock screen when the specific biometry kind is "
        "unknown (fallback copy; ADR-0009).",
        "Unlock",
        "Datgloi",
    ),
    "appLock.unlock.touchID": (
        "Primary button title on the app-lock screen when Touch ID is available (ADR-0009).",
        "Unlock with Touch ID",
        "Datgloi gyda Touch ID",
    ),
    "appLock.unlockReason": (
        "Reason string passed to the system biometric prompt (LAContext) when re-entering "
        "the app (ADR-0009).",
        "Sign back in to your catch records",
        "Mewngofnodwch yn ôl i'ch cofnodion dalfa",
    ),
    "manageAccount.faceID.enableFailed": (
        "Accessible inline error shown on \"Manage your account\" when turning the Face ID "
        "toggle on fails the live biometric enrolment check (ADR-0009) — the preference is "
        "NOT persisted in this case.",
        "We could not turn on Face ID sign-in. Check Face ID is set up on this device and "
        "try again.",
        "Ni allem droi mewngofnodi Face ID ymlaen. Gwiriwch fod Face ID wedi'i osod ar y "
        "ddyfais hon a rhowch gynnig arall arni.",
    ),
}


def entry(comment, english, welsh):
    return {
        "comment": comment,
        "extractionState": "manual",
        "localizations": {
            "cy": {"stringUnit": {"state": "needs_review", "value": welsh}},
            "en": {"stringUnit": {"state": "translated", "value": english}},
        },
    }


def main():
    data = json.loads(CATALOG.read_text(encoding="utf-8"))
    strings = data["strings"]
    added = 0
    for key, (comment, english, welsh) in NEW_KEYS.items():
        if key in strings:
            print(f"skip (exists): {key}")
            continue
        strings[key] = entry(comment, english, welsh)
        added += 1
        print(f"added: {key}")

    # Keep keys sorted so the catalog stays diff-friendly, matching Xcode's ordering.
    data["strings"] = dict(sorted(strings.items()))
    CATALOG.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"done: {added} key(s) added")
    return 0


if __name__ == "__main__":
    sys.exit(main())
