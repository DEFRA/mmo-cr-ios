#!/usr/bin/env python3
"""Add Phase 2 Settings-screen localisation keys to Localizable.xcstrings (see
docs/design-specs/settings.md): analytics-consent section, account/menu links,
and the "Gear used" row. `settings.title` already exists from Phase 1 and is
skipped idempotently.

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
    "settings.analytics.body": (
        "Body paragraph under the analytics-consent sub-heading on the Settings screen.",
        "We use this to improve the experience and stability of the app. Read more about "
        "how we use your data in our privacy notice.",
        "Rydym yn defnyddio hyn i wella profiad a sefydlogrwydd yr ap. Darllenwch fwy am "
        "sut rydym yn defnyddio'ch data yn ein hysbysiad preifatrwydd.",
    ),
    "settings.analytics.heading": (
        "Bold sub-heading introducing the analytics-consent section on the Settings screen.",
        "Optional analytics data",
        "Data dadansoddeg dewisol",
    ),
    "settings.analytics.link": (
        "Separate underlined link line below the analytics body paragraph (deviation #4 — "
        "not an inline link within the paragraph).",
        "How we use your data",
        "Sut rydym yn defnyddio'ch data",
    ),
    "settings.analytics.toggle.hint": (
        "Accessibility hint read after the analytics toggle's label, explaining what "
        "double-tapping does.",
        "Double tap to turn analytics data collection off or on",
        "Trewch ddwywaith i droi casglu data dadansoddeg ymlaen neu i ffwrdd",
    ),
    "settings.analytics.toggle.label": (
        "Authored VoiceOver accessibility label for the analytics-consent toggle — the mock "
        "has no visible label text of its own beyond the section heading (deviation #7).",
        "Analytics data collection",
        "Casglu data dadansoddeg",
    ),
    "settings.gearUsed.change": (
        "Trailing 'Change' link/action on the Gear used row.",
        "Change",
        "Newid",
    ),
    "settings.gearUsed.label": (
        "Label for the Gear used row on the Settings screen.",
        "Gear used",
        "Offer a ddefnyddiwyd",
    ),
    "settings.gearUsed.value.empty": (
        "Authored empty-state copy for the Gear used row's value when no gear has been "
        "recorded yet. The Figma mock showed the literal, un-overridden component default "
        "'Cell' here (deviation #5) — this is real, authored copy, not that placeholder.",
        "Not yet recorded",
        "Heb ei gofnodi eto",
    ),
    "settings.link.myAccount": (
        "Settings menu link — item 1.",
        "My account",
        "Fy nghyfrif",
    ),
    "settings.link.privacyNotice": (
        "Settings menu link — item 2.",
        "Privacy notice",
        "Hysbysiad preifatrwydd",
    ),
    "settings.link.signOut": (
        "Settings menu link — item 4. Rendered inert/no-op in this phase (no sign-out "
        "action wired yet) — see SettingsViewModel.signOutTapped().",
        "Sign out",
        "Allgofnodi",
    ),
    "settings.link.supportInformation": (
        "Settings menu link — item 3.",
        "Support information",
        "Gwybodaeth gymorth",
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
