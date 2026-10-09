#!/usr/bin/env python3
"""Add the "blank search field" validation keys to Localizable.xcstrings.

GOV.UK's "Be specific" guidance wants a different message for each error state: a blank
required field gets an instruction ("Enter the port you want to add"), a typed-but-unselected
field gets the existing "Select ... from the list" message. The `.select`-equivalent half of
each pair already exists (`catchRecord.addPort.validation.none` /
`catchRecord.addGear.validation.none`), so only the `.enter` half is new -- except for the
manual statistical-area screen, which gets its own pair rather than reusing the *map* screen's
`catchRecord.catchLocation.validation.none` ("Select a statistical subrectangle").

Idempotent: skips any key that already exists. Welsh values follow the phrasing already used
in this catalogue ("Rhowch ..." / "Dewiswch ...", and the manual-entry screen's own
"is-ardal ystadegol") and are marked `needs_review` pending human translation review.
"""
import json
import pathlib
import sys

CATALOG = pathlib.Path(__file__).resolve().parents[1] / "record-catch" / "Resources" / "Localizable.xcstrings"

# key -> (comment, english, welsh)
NEW_KEYS = {
    "catchRecord.addPort.validation.enter": (
        "Add-port: search field left completely blank on Save and continue.",
        "Enter the port you want to add",
        "Rhowch y porthladd rydych am ei ychwanegu",
    ),
    "catchRecord.addGear.validation.enter": (
        "Add-gear: search field left completely blank on Save and continue.",
        "Enter the gear you want to add",
        "Rhowch y gêr rydych am ei ychwanegu",
    ),
    "catchRecord.manualEntry.validation.enter": (
        "Manual statistical sub area entry: search field left completely blank.",
        "Enter the statistical sub area",
        "Rhowch yr is-ardal ystadegol",
    ),
    "catchRecord.manualEntry.validation.select": (
        "Manual statistical sub area entry: typed, but nothing picked from the results list.",
        "Select a statistical sub area from the list",
        "Dewiswch is-ardal ystadegol o'r rhestr",
    ),
}


def main() -> int:
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    strings = catalog["strings"]
    added = 0
    for key, (comment, english, welsh) in NEW_KEYS.items():
        if key in strings:
            print(f"skip (exists): {key}")
            continue
        strings[key] = {
            "comment": comment,
            "extractionState": "manual",
            "localizations": {
                "cy": {"stringUnit": {"state": "needs_review", "value": welsh}},
                "en": {"stringUnit": {"state": "translated", "value": english}},
            },
        }
        added += 1
        print(f"added: {key}")

    catalog["strings"] = dict(sorted(strings.items()))
    CATALOG.write_text(
        json.dumps(catalog, indent=2, ensure_ascii=False, sort_keys=False) + "\n",
        encoding="utf-8",
    )
    print(f"\n{added} key(s) added to {CATALOG.name}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
