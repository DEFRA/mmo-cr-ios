#!/usr/bin/env python3
"""Add TabBar, Notifications-placeholder and Settings-shell localisation keys to
Localizable.xcstrings (Phase 1 of the tab-bar navigation work — see ADR-0006).

Idempotent: skips any key that already exists. Welsh values are placeholders pending
translation and are marked `needs_review` (never a `[CY-TODO]` prefix in rendered copy).
"""
import json
import pathlib
import sys

CATALOG = pathlib.Path(__file__).resolve().parents[1] / "record-catch" / "Resources" / "Localizable.xcstrings"

# key -> (comment, english, welsh_placeholder)
NEW_KEYS = {
    "notifications.comingSoon.body": (
        "Body copy for the Notifications tab's placeholder empty state, shown until the "
        "feature is built in a later phase.",
        "There are no notifications yet. This is where you'll see updates about your catch records.",
        "Nid oes hysbysiadau eto. Dyma lle byddwch yn gweld diweddariadau am eich cofnodion dalfa.",
    ),
    "notifications.title": (
        "Page title for the Notifications tab's placeholder screen, rendered as the heading "
        "by ViewTemplate.",
        "Notifications",
        "Hysbysiadau",
    ),
    "settings.title": (
        "Page title for the minimal Phase 1 Settings tab shell, rendered as the heading by "
        "ViewTemplate. Full Settings content is added in a later phase.",
        "Settings",
        "Gosodiadau",
    ),
    "tabBar.home": (
        "Accessibility/tab-item label for the Home tab in the root TabView.",
        "Home",
        "Cartref",
    ),
    "tabBar.notifications": (
        "Accessibility/tab-item label for the Notifications tab in the root TabView.",
        "Notifications",
        "Hysbysiadau",
    ),
    "tabBar.settings": (
        "Accessibility/tab-item label for the Settings tab in the root TabView.",
        "Settings",
        "Gosodiadau",
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
