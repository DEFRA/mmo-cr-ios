#!/usr/bin/env python3
"""Add Submission Success localisation keys to Localizable.xcstrings, and remove the now-unused
Placeholder Next Step keys it replaces.

Idempotent: skips any key that already exists. Welsh values are placeholders pending
translation and are marked `needs_review` (never a `[CY-TODO]` prefix in rendered copy).
"""
import json
import pathlib
import sys

CATALOG = pathlib.Path(__file__).resolve().parents[1] / "record-catch" / "Resources" / "Localizable.xcstrings"

# key -> (comment, english, welsh_placeholder)
NEW_KEYS = {
    "catchRecord.submissionSuccess.heading": (
        "Heading rendered inside the green confirmation panel on the final submitted screen.",
        "Your catch record has been submitted",
        "Mae eich cofnod dalfa wedi'i gyflwyno",
    ),
    "catchRecord.submissionSuccess.referenceLabel": (
        "Label above the reference number inside the green confirmation panel.",
        "Your catch record reference",
        "Cyfeirnod eich cofnod dalfa",
    ),
    "catchRecord.submissionSuccess.whatHappensNext": (
        "Sub-heading introducing the bullet list of what happens next.",
        "What happens next",
        "Beth sy'n digwydd nesaf",
    ),
    "catchRecord.submissionSuccess.bullet.received": (
        "First bullet — the record has reached the fishing authority.",
        "Your catch record has been received by the relevant fishing authority",
        "Mae eich cofnod dalfa wedi dod i law'r awdurdod pysgota perthnasol",
    ),
    "catchRecord.submissionSuccess.bullet.email": (
        "Second bullet — confirmation email timing.",
        "You'll receive a confirmation email within 24 hours",
        "Byddwch yn derbyn e-bost cadarnhau o fewn 24 awr",
    ),
    "catchRecord.submissionSuccess.bullet.view": (
        "Third bullet — submitted records remain viewable in the account.",
        "You can view your submitted records in your account at any time",
        "Gallwch weld eich cofnodion a gyflwynwyd yn eich cyfrif ar unrhyw adeg",
    ),
    "catchRecord.submissionSuccess.bullet.save": (
        "Fourth bullet — prompts the user to keep the reference number.",
        "Save your catch record reference for your records",
        "Cadwch gyfeirnod eich cofnod dalfa at eich cofnodion",
    ),
    "catchRecord.submissionSuccess.viewRecords": (
        "Primary button returning to Home from the final submitted screen.",
        "View your catch records",
        "Gweld eich cofnodion dalfa",
    ),
    "catchRecord.submissionConfirmation.submitFailed": (
        "Error banner shown when the (stubbed) submission API call fails on the Confirmation screen.",
        "Could not submit your catch record. Check your connection and try again.",
        "Methwyd â chyflwyno'ch cofnod dalfa. Gwiriwch eich cysylltiad a rhowch gynnig arall arni.",
    ),
}

# Keys owned solely by the removed PlaceholderNextStep screen — now dead.
REMOVED_KEYS = {
    "catchRecord.placeholder.nextStep.heading",
    "catchRecord.placeholder.nextStep.message",
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

    removed = 0
    for key in REMOVED_KEYS:
        if key in strings:
            del strings[key]
            removed += 1
            print(f"removed: {key}")
        else:
            print(f"skip (already absent): {key}")

    # Keep keys sorted so the catalog stays diff-friendly, matching Xcode's ordering.
    data["strings"] = dict(sorted(strings.items()))
    CATALOG.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"done: {added} key(s) added, {removed} key(s) removed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
