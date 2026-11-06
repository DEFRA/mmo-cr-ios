#!/usr/bin/env python3
"""Add Entra External ID sign-in copy to Localizable.xcstrings (ADR-0022):
- signIn.error.email.invalid -- inline error for an invalid email format (ES4).
- signIn.error.service -- one provisional message covering network, service-unavailable and
  not-configured sign-in outcomes. Flagged "needs content review" in docs/design-specs/sign-in.md.
- signIn.a11y.signingIn -- VoiceOver label while the Sign In button is loading (EC1).
- signIn.a11y.hint -- accessibility hint for the Sign In button (not localized elsewhere in the
  app's other PrimaryButton call sites either -- English-only hint is an accepted existing
  pattern; see PrimaryButton.swift).

Idempotent: skips any key that already exists. Welsh values are placeholders pending
confirmation by a Welsh speaker and are marked `needs_review` (never a `[CY-TODO]` prefix in
rendered copy).
"""
import json
import pathlib
import sys

CATALOG = pathlib.Path(__file__).resolve().parents[1] / "record-catch" / "Resources" / "Localizable.xcstrings"

# key -> (comment, english, welsh_placeholder)
NEW_KEYS = {
    "signIn.error.email.invalid": (
        "Inline error when the email field is non-empty but not a valid email format (ES4, "
        "ADR-0022).",
        "Enter a valid email address",
        "Rhowch gyfeiriad e-bost dilys",
    ),
    "signIn.error.service": (
        "Provisional form-level error covering no network connectivity, an Entra/MSAL service "
        "failure, an unsupported sign-in step (MFA/browser/code required), and the "
        "'not configured' placeholder state (ADR-0022 \u00a77). NEEDS CONTENT REVIEW before "
        "release -- see docs/design-specs/sign-in.md.",
        "Sorry, there is a problem signing in. Try again later",
        "Mae'n ddrwg gennym, mae problem wrth fewngofnodi. Rhowch gynnig arall arni yn nes ymlaen",
    ),
    "signIn.a11y.signingIn": (
        "VoiceOver label for the Sign In button while a sign-in request is in flight (EC1, "
        "ADR-0022).",
        "Signing in",
        "Wrthi'n mewngofnodi",
    ),
    "signIn.a11y.hint": (
        "Accessibility hint for the Sign In button when enabled and not loading (ADR-0022).",
        "Submits your sign in details",
        "Yn cyflwyno'ch manylion mewngofnodi",
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
