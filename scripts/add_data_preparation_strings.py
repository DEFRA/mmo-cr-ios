#!/usr/bin/env python3
"""Add the "Data before Home" preparation screen's localisation keys, plus the
reference-data sync banner's keys that were never added to Localizable.xcstrings
in an earlier change (see ADR-0024 "Error UI" / "Data before Home").

Idempotent: skips any key that already exists. Welsh values are placeholder
translations pending confirmation by a Welsh speaker and are marked
`needs_review` (never a `[CY-TODO]` prefix in rendered copy).
"""
import json
import pathlib
import sys

CATALOG = pathlib.Path(__file__).resolve().parents[1] / "record-catch" / "Resources" / "Localizable.xcstrings"

# key -> (comment, english, welsh_placeholder)
NEW_KEYS = {
    "referenceData.sync.failed.tag": (
        "Red status tag shown in SyncErrorBanner when the most recent reference-data "
        "sync failed (see ADR-0024 'Error UI'). An adjective, not a verb, per GOV.UK "
        "Design System Tag guidance.",
        "Important",
        "Pwysig",
    ),
    "referenceData.sync.failed.message": (
        "Message shown in SyncErrorBanner when a reference-data sync failed but the "
        "app already has data from a previous successful sync.",
        "We could not update your fishing data. You can keep using what you already have.",
        "Ni allem ddiweddaru eich data pysgota. Gallwch barhau i ddefnyddio'r hyn sydd "
        "gennych eisoes.",
    ),
    "referenceData.sync.unavailable.message": (
        "Message shown in SyncErrorBanner when a reference-data sync failed and "
        "nothing has ever synced successfully on this device.",
        "Your fishing data has not downloaded yet. Some features may not work until this is done.",
        "Nid yw eich data pysgota wedi'i lawrlwytho eto. Mae'n bosibl na fydd rhai "
        "nodweddion yn gweithio nes bod hyn wedi'i wneud.",
    ),
    "referenceData.sync.retry": (
        "Retry link shown in SyncErrorBanner next to a failed-sync message.",
        "Try again",
        "Rhowch gynnig arall arni",
    ),
    "dataPreparation.heading": (
        "Page heading on the 'Data before Home' preparation screen shown between "
        "sign-in/unlock and Home while required reference data downloads (see "
        "ADR-0024 'Data before Home').",
        "Getting your fishing data ready",
        "Paratoi eich data pysgota",
    ),
    "dataPreparation.preparing.message": (
        "Body copy shown under the progress indicator while the required reference "
        "data (ports/species/gears) is downloading.",
        "This may take a moment.",
        "Gall hyn gymryd eiliad.",
    ),
    "dataPreparation.preparing.accessibilityLabel": (
        "VoiceOver label for the progress indicator while the required reference "
        "data is downloading.",
        "Downloading your fishing data",
        "Yn lawrlwytho eich data pysgota",
    ),
    "dataPreparation.failed.offline.message": (
        "Message shown when the required reference data could not be downloaded "
        "because the device has no network connection.",
        "You're offline. Connect to the internet to download the fishing data you need before you can start recording catches.",
        "Rydych All-lein. Cysylltwch â'r rhyngrwyd i lawrlwytho'r data pysgota sydd ei "
        "angen arnoch cyn y gallwch ddechrau cofnodi dalfeydd.",
    ),
    "dataPreparation.failed.generic.message": (
        "Message shown when the required reference data could not be downloaded for "
        "a reason other than being offline (e.g. a server error).",
        "We could not download the fishing data you need. Check your connection and try again.",
        "Ni allem lawrlwytho'r data pysgota sydd ei angen arnoch. Gwiriwch eich "
        "cysylltiad a rhowch gynnig arall arni.",
    ),
    "dataPreparation.retry": (
        "Primary button on the 'Data before Home' preparation screen's failure "
        "state, retrying the download.",
        "Try again",
        "Rhowch gynnig arall arni",
    ),
    "dataPreparation.signOut": (
        "Secondary button on the 'Data before Home' preparation screen's failure "
        "state, signing the user out rather than waiting for the download.",
        "Sign out",
        "Allgofnodi",
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
