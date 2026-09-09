#!/usr/bin/env python3
"""Add Home records-list (load/empty/error) localisation keys to Localizable.xcstrings.

Idempotent: skips any key that already exists. Welsh values are placeholders pending
translation and are marked `needs_review` (never a `[CY-TODO]` prefix in rendered copy).
"""
import json
import pathlib
import sys

CATALOG = pathlib.Path(__file__).resolve().parents[1] / "record-catch" / "Resources" / "Localizable.xcstrings"

# key -> (comment, english, welsh_placeholder)
NEW_KEYS = {
    "home.records.loading": (
        "Announced while Home's trips list is loading.",
        "Loading your trips…",
        "Wrthi'n llwytho eich teithiau…",
    ),
    "home.records.empty": (
        "Shown when there are no local or server trips to display.",
        "You have no trips yet.",
        "Nid oes gennych deithiau eto.",
    ),
    "home.records.error": (
        "Shown when the (server) records list could not be loaded. Local unsent drafts are offline-first and are not affected.",
        "We could not load your submitted trips. Check your connection and try again.",
        "Ni allem lwytho eich teithiau a gyflwynwyd. Gwiriwch eich cysylltiad a rhowch gynnig arall arni.",
    ),
    "home.records.error.retry": (
        "Retry button shown alongside the records-list error.",
        "Try again",
        "Rhowch gynnig arall arni",
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

    data["strings"] = dict(sorted(strings.items()))
    CATALOG.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"done: {added} key(s) added")
    return 0


if __name__ == "__main__":
    sys.exit(main())
