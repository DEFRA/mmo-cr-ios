#!/usr/bin/env python3
"""Add Settings "Sign out" confirmation-dialog localisation keys to Localizable.xcstrings.

Idempotent: skips any key that already exists. Welsh values are placeholders pending
translation and are marked `needs_review` (never a `[CY-TODO]` prefix in rendered copy).
"""
import json
import pathlib
import sys

CATALOG = pathlib.Path(__file__).resolve().parents[1] / "record-catch" / "Resources" / "Localizable.xcstrings"

# key -> (comment, english, welsh_placeholder)
NEW_KEYS = {
    "settings.signOut.confirm.title": (
        "Title of the confirmation dialog shown after tapping the inert 'Sign out' link "
        "(see SettingsViewModel.signOutTapped()). UI-only — no auth/session exists yet.",
        "Sign out?",
        "Allgofnodi?",
    ),
    "settings.signOut.confirm.message": (
        "Body message of the sign-out confirmation dialog.",
        "You can sign back in at any time.",
        "Gallwch fewngofnodi eto unrhyw bryd.",
    ),
    "settings.signOut.confirm.confirm": (
        "Destructive confirm button on the sign-out confirmation dialog.",
        "Sign out",
        "Allgofnodi",
    ),
    "settings.signOut.confirm.cancel": (
        "Cancel button on the sign-out confirmation dialog.",
        "Cancel",
        "Canslo",
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
