#!/usr/bin/env python3
"""Add "Manage your account" screen localisation keys to Localizable.xcstrings (see
docs/design-specs/manage-account.md): the "Business Name" caption, page title, the
"Your details" field rows (first name / last name / address / email / contact number),
the shared "Change" action, and the "Sign in" section's Face ID toggle.

Idempotent: skips any key that already exists. Welsh values are placeholders pending
translation and are marked `needs_review` (never a `[CY-TODO]` prefix in rendered copy).
Header keys (`header.back`, `header.branding`, `header.language.*`) already exist and
are reused unchanged — not added here.
"""
import json
import pathlib
import sys

CATALOG = pathlib.Path(__file__).resolve().parents[1] / "record-catch" / "Resources" / "Localizable.xcstrings"

# key -> (comment, english, welsh_placeholder)
NEW_KEYS = {
    "manageAccount.address.label": (
        "Label for the Address row on the Manage your account screen.",
        "Address",
        "Cyfeiriad",
    ),
    "manageAccount.caption": (
        "Caption shown above the 'Manage your account' page title. Literal design copy — "
        "not a data-bound business name (see design spec's deviation register).",
        "Business Name",
        "Enw'r Busnes",
    ),
    "manageAccount.change": (
        "Trailing 'Change' link/action shown on every 'Your details' field row. "
        "SettingsValueRow composes this with the row's label for its accessibility label "
        "(e.g. 'Change first name').",
        "Change",
        "Newid",
    ),
    "manageAccount.contactNumber.label": (
        "Label for the Contact number row on the Manage your account screen.",
        "Contact number",
        "Rhif cyswllt",
    ),
    "manageAccount.email.label": (
        "Label for the Email row on the Manage your account screen.",
        "Email",
        "E-bost",
    ),
    "manageAccount.faceID.heading": (
        "Bold sub-heading introducing the Face ID sign-in row under the 'Sign in' section.",
        "Face ID sign-in",
        "Mewngofnodi Face ID",
    ),
    "manageAccount.faceID.hint": (
        "Body hint under the Face ID sign-in heading.",
        "Use your Face ID instead of your password.",
        "Defnyddiwch eich Face ID yn lle eich cyfrinair.",
    ),
    "manageAccount.faceID.toggle.hint": (
        "Accessibility hint read after the Face ID toggle's label, explaining what "
        "double-tapping does. UI-only stub — no LocalAuthentication is wired up yet "
        "(see BiometricPreferenceStore).",
        "Double tap to turn Face ID sign-in off or on",
        "Trewch ddwywaith i droi mewngofnodi Face ID ymlaen neu i ffwrdd",
    ),
    "manageAccount.faceID.toggle.label": (
        "Authored VoiceOver accessibility label for the Face ID toggle — mirrors the "
        "analytics toggle's authored-label pattern (settings.analytics.toggle.label).",
        "Face ID sign-in",
        "Mewngofnodi Face ID",
    ),
    "manageAccount.firstName.label": (
        "Label for the First name row on the Manage your account screen.",
        "First name",
        "Enw cyntaf",
    ),
    "manageAccount.lastName.label": (
        "Label for the Last name row on the Manage your account screen.",
        "Last name",
        "Cyfenw",
    ),
    "manageAccount.signIn.heading": (
        "Bold section heading introducing the 'Sign in' section (Face ID row).",
        "Sign in",
        "Mewngofnodi",
    ),
    "manageAccount.title": (
        "Page title for the Manage your account screen.",
        "Manage your account",
        "Rheoli eich cyfrif",
    ),
    "manageAccount.value.notProvided": (
        "Authored empty-state copy for a 'Your details' field row when no value is "
        "recorded — defensive fallback; the stub fixture always populates every field.",
        "Not provided",
        "Heb ei ddarparu",
    ),
    "manageAccount.yourDetails.heading": (
        "Bold section heading introducing the 'Your details' field rows.",
        "Your details",
        "Eich manylion",
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
