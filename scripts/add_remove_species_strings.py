#!/usr/bin/env python3
"""Add Remove Species localisation keys to Localizable.xcstrings.

Idempotent: skips any key that already exists. Welsh values are placeholders pending
translation and are marked `needs_review` (never a `[CY-TODO]` prefix in rendered copy).
"""
import json
import pathlib
import sys

CATALOG = pathlib.Path(__file__).resolve().parents[1] / "record-catch" / "Resources" / "Localizable.xcstrings"

# key -> (comment, english, welsh_placeholder)
NEW_KEYS = {
    "catchRecord.species.remove.heading": (
        "Remove-species H1. %@ is the gear name.",
        "Remove a species caught with %@",
        "Tynnu rhywogaeth a ddaliwyd gyda %@",
    ),
    "catchRecord.species.remove.body": (
        "Remove-species intro paragraph.",
        "Select the species you want to remove, then delete them.",
        "Dewiswch y rhywogaethau rydych am eu tynnu, yna eu dileu.",
    ),
    "catchRecord.species.remove.error": (
        "Inline validation error when Delete is tapped with nothing ticked.",
        "Select at least one species to remove",
        "Dewiswch o leiaf un rhywogaeth i'w thynnu",
    ),
    "catchRecord.species.remove.delete": (
        "Button that validates the selection and opens the destructive confirmation dialog.",
        "Delete",
        "Dileu",
    ),
    "catchRecord.species.remove.cancel": (
        "Link that returns to the weights screen with no changes.",
        "Cancel",
        "Canslo",
    ),
    "catchRecord.species.remove.confirm.title": (
        "Title of the destructive confirmation dialog shown after Delete.",
        "Remove the selected species?",
        "Tynnu'r rhywogaethau a ddewiswyd?",
    ),
    "catchRecord.species.remove.confirm.message": (
        "Body message of the destructive confirmation dialog shown after Delete.",
        "This cannot be undone.",
        "Ni ellir dadwneud hyn.",
    ),
    "catchRecord.species.remove.confirm.confirm": (
        "Destructive confirm button on the remove-species confirmation dialog.",
        "Remove",
        "Tynnu",
    ),
    "catchRecord.species.remove.confirm.cancel": (
        "Cancel button on the remove-species confirmation dialog.",
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
