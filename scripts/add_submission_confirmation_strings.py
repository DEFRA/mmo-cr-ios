#!/usr/bin/env python3
"""Add Submission Confirmation localisation keys to Localizable.xcstrings.

Idempotent: skips any key that already exists. Welsh values are placeholders pending
translation and are marked `needs_review` (never a `[CY-TODO]` prefix in rendered copy).
"""
import json
import pathlib
import sys

CATALOG = pathlib.Path(__file__).resolve().parents[1] / "record-catch" / "Resources" / "Localizable.xcstrings"

# key -> (comment, english, welsh_placeholder)
NEW_KEYS = {
    "catchRecord.submissionConfirmation.heading": (
        "H1 for the final confirmation screen before submitting a completed catch record.",
        "Confirmation",
        "Cadarnhad",
    ),
    "catchRecord.submissionConfirmation.notice": (
        "Bold notice explaining what submitting the record means, shown with a leading icon.",
        "By submitting this record, you agree that the information you've given is complete and correct.",
        "Drwy gyflwyno'r cofnod hwn, rydych yn cytuno bod y wybodaeth a roddwyd gennych yn gyflawn ac yn gywir.",
    ),
    "catchRecord.submissionConfirmation.body": (
        "Intro line for the bullet list of what submission confirms.",
        "By submitting your catch record, you're confirming",
        "Drwy gyflwyno'ch cofnod dalfa, rydych yn cadarnhau",
    ),
    "catchRecord.submissionConfirmation.bullet.weight": (
        "First bullet — accuracy of landed weight.",
        "The weight of fish you have landed is accurate",
        "Bod pwysau'r pysgod rydych wedi'u glanio yn gywir",
    ),
    "catchRecord.submissionConfirmation.bullet.tolerance": (
        "Second bullet — within permitted tolerance levels.",
        "This is within permitted tolerance levels",
        "Bod hyn o fewn y lefelau goddefiant a ganiateir",
    ),
    "catchRecord.submissionConfirmation.bullet.action": (
        "Third bullet — enforcement consequence of inaccurate recording.",
        "Fishing authorities may take action in respect of inaccurate catch recording",
        "Gall awdurdodau pysgota gymryd camau mewn perthynas â chofnodi dalfa anghywir",
    ),
    "catchRecord.submissionConfirmation.confirmCheckbox": (
        "Label for the single required confirmation checkbox.",
        "I confirm the information is complete and accurate",
        "Rwy'n cadarnhau bod y wybodaeth yn gyflawn ac yn gywir",
    ),
    "catchRecord.submissionConfirmation.validation.none": (
        "Inline error shown when Accept and submit is tapped without ticking the checkbox.",
        "Confirm that the information is complete and accurate before continuing",
        "Cadarnhewch fod y wybodaeth yn gyflawn ac yn gywir cyn parhau",
    ),
    "catchRecord.submissionConfirmation.accept": (
        "Primary button label that submits the completed catch record.",
        "Accept and submit trip details",
        "Derbyn a chyflwyno manylion y daith",
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
