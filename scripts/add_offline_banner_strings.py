#!/usr/bin/env python3
"""Add the offline-connectivity banner's localisation keys to Localizable.xcstrings
(see ADR-0019 and docs/design-specs/offline-banner.md).

Idempotent: skips any key that already exists. Welsh values are placeholder
translations pending confirmation by a Welsh speaker and are marked
`needs_review` (never a `[CY-TODO]` prefix in rendered copy). In particular,
"dalfa" (the fisheries sense of "catch") should be checked against MMO house
style by a Welsh-speaking reviewer before these reach production.
"""
import json
import pathlib
import sys

CATALOG = pathlib.Path(__file__).resolve().parents[1] / "record-catch" / "Resources" / "Localizable.xcstrings"

# key -> (comment, english, welsh_placeholder)
NEW_KEYS = {
    "connectivity.offline.tag": (
        "Red status tag shown in the offline banner (see ADR-0019 and "
        "docs/design-specs/offline-banner.md). An adjective, not a verb, per "
        "GOV.UK Design System Tag guidance.",
        "Offline",
        "All-lein",
    ),
    "connectivity.offline.message": (
        "Message shown beside the 'Offline' tag in the offline banner, rendered "
        "under the header on every ViewTemplate screen while the device has no "
        "network path.",
        "You can still record your catch. Your record will be saved and sent "
        "when you're back online.",
        "Gallwch barhau i gofnodi eich dalfa. Bydd eich cofnod yn cael ei gadw "
        "a'i anfon pan fyddwch chi'n ôl ar-lein.",
    ),
    "connectivity.offline.announcement": (
        "VoiceOver announcement posted when the device transitions from online "
        "to offline (WCAG 2.2 4.1.3 Status Messages). Posted at high priority "
        "since it should interrupt.",
        "Offline. You can still record your catch. Your record will be saved "
        "and sent when you're back online.",
        "All-lein. Gallwch barhau i gofnodi eich dalfa. Bydd eich cofnod yn "
        "cael ei gadw a'i anfon pan fyddwch chi'n ôl ar-lein.",
    ),
    "connectivity.online.announcement": (
        "VoiceOver announcement posted when the device transitions from "
        "offline back to online (WCAG 2.2 4.1.3 Status Messages — conveys the "
        "removal of the offline status, not just its presence). Posted at "
        "default priority since it is informational, not urgent.",
        "Back online.",
        "Yn ôl ar-lein.",
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
