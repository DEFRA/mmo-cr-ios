#!/usr/bin/env python3
"""Add the Select vessel screen's loading/empty-state localisation keys to
Localizable.xcstrings (ADR-0024/ADR-0028): vessels are now real, API-sourced data rather than a
static two-vessel list, so the screen needs its own loading and "no vessels" states.

Idempotent: skips any key that already exists. Welsh values are placeholder translations pending
confirmation by a Welsh speaker and are marked `needs_review`.
"""
import json
import pathlib
import sys

CATALOG = pathlib.Path(__file__).resolve().parents[1] / "record-catch" / "Resources" / "Localizable.xcstrings"

# key -> (comment, english, welsh_placeholder)
NEW_KEYS = {
    "catchRecord.selectVessel.loading": (
        "Accessibility label/visible-adjacent text for the loading spinner shown while "
        "SelectVesselViewModel.load() reads the on-device vessel list (ADR-0024/ADR-0028).",
        "Loading vessels…",
        "Wrthi'n llwytho llongau…",
    ),
    "catchRecord.selectVessel.empty.message": (
        "Shown on the Select vessel screen when the signed-in user has no vessels available to "
        "select — either nothing has been downloaded yet, or their account has no vessels linked "
        "(ADR-0024/ADR-0028). Never an indefinite spinner (accessibility.instructions.md).",
        "No vessels are linked to your account. Contact MMO support for help.",
        "Nid oes llongau wedi'u cysylltu â'ch cyfrif. Cysylltwch â chymorth MMO am help.",
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
