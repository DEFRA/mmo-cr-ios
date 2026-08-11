#!/usr/bin/env python3
"""Add Submission Nudge localisation keys to Localizable.xcstrings.

Idempotent: skips any key that already exists. Welsh values are placeholders pending
translation and are marked `needs_review` (never a `[CY-TODO]` prefix in rendered copy).
"""
import json
import pathlib
import sys

CATALOG = pathlib.Path(__file__).resolve().parents[1] / "record-catch" / "Resources" / "Localizable.xcstrings"

# key -> (comment, english, welsh_placeholder)
NEW_KEYS = {
    "catchRecord.submissionNudge.heading": (
        "H1 for the late-submission nudge. %lld is the whole number of days after the trip end date.",
        "This catch record is being submitted %lld days after the trip end date",
        "Mae'r cofnod dalfa hwn yn cael ei gyflwyno %lld diwrnod ar ôl dyddiad diwedd y daith",
    ),
    "catchRecord.submissionNudge.body": (
        "Guidance paragraph on the late-submission nudge.",
        "Catch records must be submitted within 24 hours of a trip ending.",
        "Rhaid cyflwyno cofnodion dalfa o fewn 24 awr i daith yn dod i ben.",
    ),
    "catchRecord.submissionNudge.checkDateLink": (
        "Link that returns to the trip end date screen to correct the date.",
        "Check the trip end date is correct before you continue",
        "Gwiriwch fod dyddiad diwedd y daith yn gywir cyn i chi barhau",
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
