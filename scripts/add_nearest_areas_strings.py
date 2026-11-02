#!/usr/bin/env python3
"""Add the "Select the statistical sub area…" nearest-areas screen's own localisation keys to
Localizable.xcstrings (reached from CatchLocationView's "Other" button — see
docs/design-specs/create-catch-record.md).

Every other piece of copy on this screen (hints, the "Other" row label, "Save and continue")
reuses existing keys already in the catalog (catchRecord.catchLocation.hint.*,
catchRecord.catchLocation.otherButton, catchRecord.saveContinue) — only the heading and the
validation message are new.

Idempotent: skips any key that already exists. Welsh values are placeholder translations pending
confirmation by a Welsh speaker and are marked `needs_review` (never a `[CY-TODO]` prefix in
rendered copy).
"""
import json
import pathlib
import sys

CATALOG = pathlib.Path(__file__).resolve().parents[1] / "record-catch" / "Resources" / "Localizable.xcstrings"

# key -> (comment, english, welsh_placeholder)
NEW_KEYS = {
    "catchRecord.nearestAreas.heading": (
        "Heading for the 'Select the statistical sub area…' nearest-areas screen "
        "(CatchLocationNearestAreasView), reached from the catch-location map's 'Other' "
        "button. %@ is the gear's description with measurements (see "
        "GearOption.descriptionWithMeasurements), matching catchRecord.catchLocation.heading's "
        "placeholder. Copy follows the supplied Figma design as-is (a recorded deviation from "
        "GOV.UK question-heading style, which avoids a trailing '?' on an instruction) — see "
        "docs/design-specs/create-catch-record.md.",
        "Select the statistical sub area where the majority of your catch was caught using %@?",
        "Dewiswch yr is-ardal ystadegol lle cafodd y rhan fwyaf o'ch dalfa ei dal gan ddefnyddio %@?",
    ),
    "catchRecord.nearestAreas.validation.none": (
        "Inline validation error on the nearest-areas screen when 'Save and continue' is "
        "pressed with nothing selected (no area and not 'Other') — "
        "CatchLocationNearestAreasValidation.errorKey(for:).",
        "Select the statistical sub area where most of your catch was caught",
        "Dewiswch yr is-ardal ystadegol lle cafodd y rhan fwyaf o'ch dalfa ei dal",
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
