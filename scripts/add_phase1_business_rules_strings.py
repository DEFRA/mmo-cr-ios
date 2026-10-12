#!/usr/bin/env python3
"""Add the Phase 1 business-rule remediation localisation keys to
Localizable.xcstrings (see the "Phase 1" plan: AC02 rolling trip-date limit,
AC12 status-tag localisation, AC11 saved-but-not-yet-sent submission screen).

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
    # --- AC02: rolling 365-day trip-date limit (BR-CAT-006) ---
    "catchRecord.tripDate.adjustedForAgeLimit.tag": (
        "Tag for the informational notice shown on the departure-date screen "
        "when a resumed draft's previously-captured date has been moved "
        "forward because the service's rolling 365-day limit has since moved "
        "past it (BR-CAT-006/AC02). Matches the WarningBox 'Important' tag "
        "pattern used elsewhere (e.g. home.warning.tag).",
        "Important",
        "Pwysig",
    ),
    "catchRecord.tripDate.adjustedForAgeLimit.message": (
        "Body message for the same notice. %@ substitutes the earliest "
        "selectable date, long-formatted (see CatchRecordDateRules.longDateString).",
        "We've updated the date you entered because the service only accepts "
        "trip dates from %@ onwards. Check it's still correct.",
        "Rydym wedi diweddaru'r dyddiad a nodwyd gennych oherwydd mai dim ond "
        "dyddiadau mordaith o %@ ymlaen y mae'r gwasanaeth yn eu derbyn. "
        "Gwiriwch ei fod yn dal yn gywir.",
    ),
    # --- AC12: localised status tags (home records table) ---
    "home.table.status.submitted": (
        "Localised text for the 'Submitted' status tag in the Home records "
        "table (see SubmissionStatus). Matches home.help.submitted.heading "
        "without the trailing colon.",
        "Submitted",
        "Wedi'i gyflwyno",
    ),
    "home.table.status.amended": (
        "Localised text for the 'Amended' status tag in the Home records "
        "table. Matches home.help.amended.heading without the trailing colon.",
        "Amended",
        "Wedi'i ddiwygio",
    ),
    "home.table.status.unsent": (
        "Localised text for the 'Unsent' status tag in the Home records "
        "table. Matches home.help.unsent.heading without the trailing colon.",
        "Unsent",
        "Heb ei anfon",
    ),
    "home.table.status.late": (
        "Localised text for the 'Late' status tag in the Home records "
        "table. Matches home.help.late.heading without the trailing colon.",
        "Late",
        "Hwyr",
    ),
    # --- AC11: saved-on-device, not-yet-submitted screen (shown when the
    # submission attempt is made while offline) ---
    "catchRecord.submissionSaved.heading": (
        "H1 for the screen shown when 'Accept and submit trip details' is "
        "confirmed while the device is offline: the record is kept locally, "
        "not submitted (BR-SUB-008/AC10/AC11).",
        "Your catch record has been saved",
        "Mae eich cofnod dalfa wedi'i gadw",
    ),
    "catchRecord.submissionSaved.body": (
        "Body copy explaining the record is saved on-device and not yet "
        "sent. Deliberately does not promise automatic background "
        "submission on reconnect — that capability does not exist yet (see "
        "ADR-0019 'Follow-up'); the user is told to open the app again to "
        "submit once back online.",
        "There's no internet connection, so your record has not been "
        "submitted yet. It's saved on this device — open the app and submit "
        "it again once you're back online.",
        "Nid oes cysylltiad rhyngrwyd, felly nid yw eich cofnod wedi'i "
        "gyflwyno eto. Mae wedi'i gadw ar y ddyfais hon — agorwch yr ap a'i "
        "gyflwyno eto unwaith y byddwch yn ôl ar-lein.",
    ),
    "catchRecord.submissionSaved.viewRecords": (
        "Primary button on the saved-not-sent screen, returning to Home "
        "(mirrors catchRecord.submissionSuccess.viewRecords).",
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
