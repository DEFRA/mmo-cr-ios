#!/usr/bin/env python3
"""Update Submission Saved (offline) screen copy in Localizable.xcstrings to match the approved
blue "Your catch record has been recorded" design, and add the new keys it introduces (reference
label inside the panel, "Send your catch record..." sub-heading, the "Check your catch records"
link + its continuation sentence, and the 24-hour WarningBox reminder).

Idempotent: always upserts the listed keys to the given (comment, english, welsh) tuple, so
re-running produces the same end state. Welsh values are placeholders pending translation and are
marked `needs_review` (never a `[CY-TODO]` prefix in rendered copy).
"""
import json
import pathlib
import sys

CATALOG = pathlib.Path(__file__).resolve().parents[1] / "record-catch" / "Resources" / "Localizable.xcstrings"

# key -> (comment, english, welsh_placeholder)
KEYS = {
    "catchRecord.submissionSaved.heading": (
        "H1 rendered inside the blue confirmation panel on the screen shown when 'Accept and "
        "submit trip details' is confirmed while the device is offline: the record is kept "
        "locally, not submitted (BR-SUB-008/AC10/AC11).",
        "Your catch record has been recorded",
        "Mae eich cofnod dalfa wedi'i gofnodi",
    ),
    "catchRecord.submissionSaved.referenceLabel": (
        "Label above the reference number inside the blue confirmation panel (mirrors "
        "catchRecord.submissionSuccess.referenceLabel).",
        "Your catch record reference",
        "Cyfeirnod eich cofnod dalfa",
    ),
    "catchRecord.submissionSaved.sendHeading": (
        "Sub-heading introducing the explanation of what the user still needs to do while offline.",
        "Send your catch record to complete this submission",
        "Anfonwch eich cofnod dalfa i gwblhau'r cyflwyniad hwn",
    ),
    "catchRecord.submissionSaved.body": (
        "Paragraph explaining the record is saved on-device and will be sent automatically once "
        "back online. Rendered as plain body copy beneath the sub-heading (no longer inside the "
        "WarningBox — see catchRecord.submissionSaved.warning for the 24-hour reminder now shown "
        "there).",
        "Your catch record has been saved and will be sent automatically when you next have a "
        "mobile signal or Wi-Fi connection.",
        "Mae eich cofnod dalfa wedi'i gadw a bydd yn cael ei anfon yn awtomatig y tro nesaf y bydd "
        "gennych signal symudol neu gysylltiad Wi-Fi.",
    ),
    "catchRecord.submissionSaved.checkRecordsLink": (
        "Standalone tappable link (not in-string markdown) that returns to Home/the catch records "
        "list, immediately followed by catchRecord.submissionSaved.checkRecordsBody.",
        "Check your catch records",
        "Gwiriwch eich cofnodion dalfa",
    ),
    "catchRecord.submissionSaved.checkRecordsBody": (
        "Continuation sentence directly after the 'Check your catch records' link.",
        "to make sure the status changes to Submitted. You are responsible for making sure we "
        "receive it.",
        "i wneud yn siŵr bod y statws yn newid i Wedi'i gyflwyno. Chi sy'n gyfrifol am wneud yn "
        "siŵr ein bod yn ei dderbyn.",
    ),
    "catchRecord.submissionSaved.warning": (
        "Message shown inside the 'Important' WarningBox, reminding the user of the 24-hour "
        "submission window even though this record is only saved, not yet sent.",
        "You must record your catch within 24 hours of landing.",
        "Rhaid i chi gofnodi'ch dalfa o fewn 24 awr i'r glanio.",
    ),
    "catchRecord.submissionSaved.viewRecords": (
        "Primary button on the saved-not-sent screen, returning to Home (mirrors "
        "catchRecord.submissionSuccess.viewRecords).",
        "View your catch records",
        "Gweld eich cofnodion dalfa",
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
    updated = 0
    for key, (comment, english, welsh) in KEYS.items():
        action = "updated" if key in strings else "added"
        strings[key] = entry(comment, english, welsh)
        if action == "added":
            added += 1
        else:
            updated += 1
        print(f"{action}: {key}")

    # Keep keys sorted so the catalog stays diff-friendly, matching Xcode's ordering.
    data["strings"] = dict(sorted(strings.items()))
    CATALOG.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"done: {added} key(s) added, {updated} key(s) updated")
    return 0


if __name__ == "__main__":
    sys.exit(main())
