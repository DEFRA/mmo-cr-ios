#!/usr/bin/env python3
"""Add the "How to record a catch" Home-screen disclosure section's
localisation keys to Localizable.xcstrings (see docs/design-specs/home.md).

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
    "home.howToRecord.title": (
        "Disclosure title for the 'How to record a catch' section on Home, "
        "positioned above 'Understanding catch record statuses'.",
        "How to record a catch",
        "Sut i gofnodi dalfa",
    ),
    "home.howToRecord.whatYouNeedToDo.heading": (
        "Bold sub-heading, first block of the How-to-record section.",
        "What you need to do",
        "Beth sydd angen i chi ei wneud",
    ),
    "home.howToRecord.whatYouNeedToDo.body1": (
        "First paragraph under 'What you need to do'.",
        "You must record all catches unless an exemption applies.",
        "Rhaid i chi gofnodi pob dalfa oni bai bod eithriad yn berthnasol.",
    ),
    "home.howToRecord.whatYouNeedToDo.body2": (
        "Second paragraph under 'What you need to do'.",
        "We'll ask whether you caught any species subject to catch limits (quota).",
        "Byddwn yn gofyn a wnaethoch ddal unrhyw rywogaethau sy'n ddarostyngedig i "
        "derfynau dalfa (cwota).",
    ),
    "home.howToRecord.whenToCreate.heading": (
        "Bold sub-heading, second block of the How-to-record section.",
        "When to create your record",
        "Pryd i greu eich cofnod",
    ),
    "home.howToRecord.whenToCreate.intro": (
        "Intro paragraph immediately before the 3-item bullet list explaining "
        "when to create a catch record.",
        "Create your catch record before moving your catch off the vessel if you:",
        "Crëwch eich cofnod dalfa cyn symud eich dalfa oddi ar y llong os ydych chi:",
    ),
    "home.howToRecord.whenToCreate.bullet.quota": (
        "Bullet 1 of 3 under 'When to create your record'.",
        "caught any species subject to catch limits (quota)",
        "wedi dal unrhyw rywogaethau sy'n ddarostyngedig i derfynau dalfa (cwota)",
    ),
    "home.howToRecord.whenToCreate.bullet.nonQuota": (
        "Bullet 2 of 3 under 'When to create your record'.",
        "caught only non-quota species",
        "wedi dal rhywogaethau di-gwota yn unig",
    ),
    "home.howToRecord.whenToCreate.bullet.icesBoundary": (
        "Bullet 3 of 3 under 'When to create your record'.",
        "crossed an ICES area boundary while fishing",
        "wedi croesi ffin ardal ICES wrth bysgota",
    ),
    "home.howToRecord.whenToCreate.deadline": (
        "Closing paragraph under 'When to create your record', after the bullet list.",
        "You need to create your catch record within 24 hours of landing your catch.",
        "Mae angen i chi greu eich cofnod dalfa o fewn 24 awr i lanio eich dalfa.",
    ),
    "home.howToRecord.icesAreas.heading": (
        "Bold sub-heading, third block of the How-to-record section.",
        "Special cases: ICES areas",
        "Achosion arbennig: ardaloedd ICES",
    ),
    "home.howToRecord.icesAreas.body1": (
        "First paragraph under 'Special cases: ICES areas'.",
        "If you fish in or cross ICES areas 4c, 7d or 7e, you must create a "
        "separate catch record each time you cross a boundary.",
        "Os ydych chi'n pysgota yn ardaloedd ICES 4c, 7d neu 7e neu'n eu croesi, "
        "rhaid i chi greu cofnod dalfa ar wahân bob tro y byddwch yn croesi ffin.",
    ),
    "home.howToRecord.icesAreas.body2": (
        "Second paragraph under 'Special cases: ICES areas'. NOTE: copied "
        "verbatim from the supplied design mock, which appears to reuse web-"
        "service copy — flagged for content review since this text is shown "
        "inside the mobile app itself (see change summary).",
        "If you need to record catches without an internet connection, use the mobile app.",
        "Os oes angen i chi gofnodi dalfeydd heb gysylltiad rhyngrwyd, defnyddiwch yr ap symudol.",
    ),
    "home.howToRecord.getHelp.heading": (
        "Bold sub-heading, fourth block of the How-to-record section.",
        "Get help with your record",
        "Cael help gyda'ch cofnod",
    ),
    "home.howToRecord.getHelp.phone": (
        "First paragraph under 'Get help with your record' — support phone "
        "number and opening hours.",
        "Call 0300 020 3788, Monday to Friday, 9am to 5pm.",
        "Ffoniwch 0300 020 3788, dydd Llun i ddydd Gwener, 9am i 5pm.",
    ),
    "home.howToRecord.getHelp.callCost": (
        "Second paragraph under 'Get help with your record' — call-cost notice.",
        "Calls to 03 numbers cost the same as calls to 01 or 02 numbers.",
        "Mae galwadau i rifau 03 yn costio'r un fath â galwadau i rifau 01 neu 02.",
    ),
    "home.howToRecord.getHelp.outOfHours": (
        "Third paragraph under 'Get help with your record' — out-of-hours "
        "automated line notice.",
        "Outside these hours, leave a catch record on our automated line.",
        "Y tu allan i'r oriau hyn, gadewch gofnod dalfa ar ein llinell awtomataidd.",
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
