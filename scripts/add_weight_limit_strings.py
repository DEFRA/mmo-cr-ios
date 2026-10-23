#!/usr/bin/env python3
"""Add the weight-validation defect-fix localisation keys to Localizable.xcstrings
(see the weight-validation fix for TC-12/AC7 "discarded weight must not reach or
exceed retained weight" and Scenario 10 "maximum catch weight of 10,000kg").

Idempotent: skips any key that already exists. Welsh values are placeholder
translations pending confirmation by a Welsh speaker and are marked
`needs_review`.
"""
import json
import pathlib
import sys

CATALOG = pathlib.Path(__file__).resolve().parents[1] / "record-catch" / "Resources" / "Localizable.xcstrings"

# key -> (comment, english, welsh_placeholder)
NEW_KEYS = {
    "catchRecord.species.weight.validation.max": (
        "Species weight error: the entered weight exceeds the maximum catch "
        "weight limit of 10,000kg (Scenario 10 of the weight-validation "
        "defect fix). %@ is the species name. Applies to every weight field "
        "sharing SpeciesWeightValidation.formatErrorMessage (the "
        "record-weights screen's 'above minimum'/'below minimum'/'legally "
        "discarded' fields, and the landing-storage species weight field).",
        "The weight for %@ must be 10,000kg or less",
        "Rhaid i'r pwysau ar gyfer %@ fod yn 10,000kg neu lai",
    ),
    "catchRecord.species.weight.validation.discardedExceedsRetained": (
        "Species weight error shown on the 'legally discarded' field when "
        "it is greater than or equal to the 'above minimum size retained' "
        "weight for the same species (AC7/TC-12 of the weight-validation "
        "defect fix — discarding at least as much as was retained does not "
        "make sense). %@ is the species name. Only raised once both fields "
        "are otherwise valid (see "
        "RecordSpeciesWeightsValidation.discardedExceedsRetainedMessage).",
        "The weight above minimum size retained for %@ must be higher than "
        "the weight legally discarded",
        "Rhaid i'r pwysau uwchlaw'r maint lleiaf a gadwyd ar gyfer %@ fod yn "
        "uwch na'r pwysau a daflwyd yn gyfreithlon",
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
