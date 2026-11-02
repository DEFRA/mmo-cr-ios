#!/usr/bin/env python3
"""Add Sign In "Create an account" disclosure copy to Localizable.xcstrings (see
docs/design-specs/sign-in.md): the GDS-style disclosure revealing vessel-owner and
skipper/agent guidance.

Idempotent: skips any key that already exists. Welsh values are placeholders pending
confirmation by a Welsh speaker and are marked `needs_review` (never a `[CY-TODO]`
prefix in rendered copy).
"""
import json
import pathlib
import sys

CATALOG = pathlib.Path(__file__).resolve().parents[1] / "record-catch" / "Resources" / "Localizable.xcstrings"

# key -> (comment, english, welsh_placeholder)
NEW_KEYS = {
    "signIn.createAccount.skipper.body": (
        "Body paragraph under the 'Skipper or agent' sub-heading in the Sign In "
        "'Create an account' disclosure.",
        "Ask your vessel owner to add you. They can do this from their account.",
        "Gofynnwch i berchennog eich llong eich ychwanegu. Gallant wneud hyn o'u cyfrif.",
    ),
    "signIn.createAccount.skipper.heading": (
        "Bold sub-heading in the Sign In 'Create an account' disclosure, for skippers/agents "
        "who must be added by their vessel owner.",
        "Skipper or agent:",
        "Sgipper neu asiant:",
    ),
    "signIn.createAccount.vesselOwner.body": (
        "Body paragraph under the 'Vessel owner' sub-heading in the Sign In "
        "'Create an account' disclosure.",
        "You will receive an email invitation to register when your vessel is added to the "
        "system.",
        "Byddwch yn derbyn gwahoddiad drwy e-bost i gofrestru pan fydd eich llong yn cael ei "
        "hychwanegu at y system.",
    ),
    "signIn.createAccount.vesselOwner.heading": (
        "Bold sub-heading in the Sign In 'Create an account' disclosure, for vessel owners who "
        "are invited automatically.",
        "Vessel owner:",
        "Perchennog llong:",
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
