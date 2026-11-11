#!/usr/bin/env python3
"""Add the self-service password reset journey's copy to Localizable.xcstrings (ADR-0027).

Idempotent: skips any key that already exists. Welsh values are machine-drafted placeholders
pending confirmation by a Welsh speaker and are marked `needs_review`. The password-requirements
hint and the generic service-error message are flagged NEEDS CONTENT REVIEW.
"""
import json
import pathlib
import sys

CATALOG = pathlib.Path(__file__).resolve().parents[1] / "record-catch" / "Resources" / "Localizable.xcstrings"

NEW_KEYS = {
    "passwordReset.reset.heading": (
        "'Reset your password' screen heading (AC1, ADR-0027).",
        "Reset your password",
        "Ailosod eich cyfrinair",
    ),
    "passwordReset.reset.guidance": (
        "Guidance on the 'Reset your password' screen (AC1).",
        "Enter the email address you use to sign in.",
        "Rhowch y cyfeiriad e-bost rydych yn ei ddefnyddio i fewngofnodi.",
    ),
    "passwordReset.email.label": (
        "Email address field label on the 'Reset your password' screen (AC1).",
        "Email address",
        "Cyfeiriad e-bost",
    ),
    "passwordReset.email.hint": (
        "Hint under the email field, deliberately generic so the app never confirms or denies "
        "an account exists for the entered address (AC3 security note, ADR-0027 \u00a73).",
        "If an account exists for this email address, we'll send a reset code.",
        "Os oes cyfrif yn bodoli ar gyfer y cyfeiriad e-bost hwn, byddwn yn anfon cod ailosod.",
    ),
    "passwordReset.email.error.empty": (
        "Inline error when the email field is blank on submit (AC2).",
        "Enter your email address",
        "Rhowch eich cyfeiriad e-bost",
    ),
    "passwordReset.email.error.invalid": (
        "Inline error when the email field is non-empty but not a valid email format (AC2).",
        "Enter a valid email address",
        "Rhowch gyfeiriad e-bost dilys",
    ),
    "passwordReset.sendCode.button": (
        "'Send reset code' button on the 'Reset your password' screen (AC1/AC3).",
        "Send reset code",
        "Anfon cod ailosod",
    ),
    "passwordReset.sendCode.a11y.hint": (
        "Accessibility hint for the 'Send reset code' button.",
        "Requests a password reset code by email",
        "Yn gofyn am god ailosod cyfrinair drwy e-bost",
    ),
    "passwordReset.a11y.sending": (
        "VoiceOver label while the 'Send reset code' button is loading.",
        "Sending",
        "Wrthi'n anfon",
    ),
    "passwordReset.enterCode.heading": (
        "'Enter your reset code' screen heading (AC5).",
        "Enter your reset code",
        "Rhowch eich cod ailosod",
    ),
    "passwordReset.enterCode.guidance": (
        "Guidance on the 'Enter your reset code' screen (AC5).",
        "Enter the code we sent to your email address.",
        "Rhowch y cod a anfonwyd atoch i'ch cyfeiriad e-bost.",
    ),
    "passwordReset.code.label": (
        "Reset code field label (AC5).",
        "Reset code",
        "Cod ailosod",
    ),
    "passwordReset.code.error.empty": (
        "Inline error when the reset-code field is blank on submit (AC6).",
        "Enter the reset code",
        "Rhowch y cod ailosod",
    ),
    "passwordReset.code.error.invalid": (
        "Inline error when the entered reset code is incorrect (AC7).",
        "The reset code you entered is incorrect. Check the code and try again",
        "Mae'r cod ailosod a roddwyd gennych yn anghywir. Gwiriwch y cod a rhowch gynnig arall arni _(needs_review)_",
    ),
    "passwordReset.code.error.expired": (
        "Inline error when the entered reset code has expired (AC8).",
        "This reset code has expired. Select 'Send a new code' to get a new one",
        "Mae'r cod ailosod hwn wedi dod i ben. Dewiswch 'Anfon cod newydd' i gael un newydd _(needs_review)_",
    ),
    "passwordReset.continue.button": (
        "'Continue' button on the 'Enter your reset code' screen (AC5/AC10).",
        "Continue",
        "Parhau",
    ),
    "passwordReset.continue.a11y.hint": (
        "Accessibility hint for the 'Continue' button on the reset-code screen.",
        "Validates your reset code",
        "Yn dilysu'ch cod ailosod",
    ),
    "passwordReset.a11y.verifying": (
        "VoiceOver label while the 'Continue' button on the reset-code screen is loading.",
        "Verifying",
        "Wrthi'n dilysu",
    ),
    "passwordReset.sendNewCode.button": (
        "'Send a new code' button on the 'Enter your reset code' screen (AC9).",
        "Send a new code",
        "Anfon cod newydd",
    ),
    "passwordReset.createPassword.heading": (
        "'Create a new password' screen heading (AC11).",
        "Create a new password",
        "Creu cyfrinair newydd",
    ),
    "passwordReset.newPassword.label": (
        "New password field label (AC11).",
        "New password",
        "Cyfrinair newydd",
    ),
    "passwordReset.newPassword.hint": (
        "Password requirement guidance under the new-password field. NEEDS CONTENT REVIEW: "
        "Entra's real policy requires 8-256 characters and 3 of 4 character classes "
        "(upper/lower/number/symbol) -- ADR-0027 \u00a76 -- this copy should be confirmed with "
        "product/content design before release.",
        "Your password must be at least 8 characters and include 3 of the following: "
        "uppercase letters, lowercase letters, numbers and symbols",
        "Rhaid i'ch cyfrinair fod o leiaf 8 nod a chynnwys 3 o'r canlynol: priflythrennau, "
        "llythrennau bach, rhifau a symbolau _(needs_review)_",
    ),
    "passwordReset.newPassword.error.empty": (
        "Inline error when the new-password field is blank on submit (AC15).",
        "Enter a new password",
        "Rhowch gyfrinair newydd",
    ),
    "passwordReset.newPassword.error.requirements": (
        "Inline error when the new password does not meet the length/character-class "
        "requirements (AC13). NEEDS CONTENT REVIEW alongside the hint above.",
        "Your password must be at least 8 characters and include 3 of the following: "
        "uppercase letters, lowercase letters, numbers and symbols",
        "Rhaid i'ch cyfrinair fod o leiaf 8 nod a chynnwys 3 o'r canlynol: priflythrennau, "
        "llythrennau bach, rhifau a symbolau _(needs_review)_",
    ),
    "passwordReset.newPassword.error.tooLong": (
        "Inline error when the new password exceeds Entra's maximum length (256 characters).",
        "Your password must be 256 characters or fewer",
        "Rhaid i'ch cyfrinair fod yn 256 nod neu lai _(needs_review)_",
    ),
    "passwordReset.confirmPassword.label": (
        "Confirm new password field label (AC11).",
        "Confirm new password",
        "Cadarnhau'r cyfrinair newydd",
    ),
    "passwordReset.confirmPassword.error.empty": (
        "Inline error when the confirm-password field is blank on submit (AC15).",
        "Enter your new password again",
        "Rhowch eich cyfrinair newydd eto",
    ),
    "passwordReset.confirmPassword.error.mismatch": (
        "Inline error when 'Confirm new password' does not match 'New password' (AC14).",
        "The passwords you entered do not match",
        "Nid yw'r cyfrineiriau a roddwyd gennych yn cyd-fynd _(needs_review)_",
    ),
    "passwordReset.password.show": (
        "'Show' text button revealing a masked password field (AC12, ADR-0027 \u00a79 "
        "deviation #2 -- a text button, not the app's usual eye icon).",
        "Show",
        "Dangos",
    ),
    "passwordReset.password.hide": (
        "'Hide' text button masking a visible password field (AC12).",
        "Hide",
        "Cuddio",
    ),
    "passwordReset.password.a11y.show": (
        "Accessibility label for the 'Show' password toggle when the password is currently masked.",
        "Show password",
        "Dangos y cyfrinair",
    ),
    "passwordReset.password.a11y.hide": (
        "Accessibility label for the 'Hide' password toggle when the password is currently visible.",
        "Hide password",
        "Cuddio'r cyfrinair",
    ),
    "passwordReset.savePassword.button": (
        "'Save new password' button on the 'Create a new password' screen (AC11/AC16). Fixes "
        "the supplied design's apparent typo ('Save new pasword') -- ADR-0027 \u00a79 deviation #3.",
        "Save new password",
        "Cadw'r cyfrinair newydd",
    ),
    "passwordReset.savePassword.a11y.hint": (
        "Accessibility hint for the 'Save new password' button.",
        "Saves your new password",
        "Yn cadw'ch cyfrinair newydd",
    ),
    "passwordReset.a11y.saving": (
        "VoiceOver label while the 'Save new password' button is loading.",
        "Saving",
        "Wrthi'n cadw",
    ),
    "passwordReset.complete.heading": (
        "Confirmation screen heading once the password has been reset (AC17).",
        "Your password has been reset",
        "Mae eich cyfrinair wedi'i ailosod",
    ),
    "passwordReset.error.service": (
        "Provisional form-level error covering no network connectivity, an Entra/MSAL service "
        "failure, and the 'not configured' placeholder state across every password-reset step "
        "(ADR-0027, mirrors signIn.error.service). NEEDS CONTENT REVIEW before release.",
        "Sorry, there is a problem with the service. Try again later",
        "Mae'n ddrwg gennym, mae problem gyda'r gwasanaeth. Rhowch gynnig arall arni yn nes ymlaen "
        "_(needs_review)_",
    ),
    "passwordReset.error.sessionExpired": (
        "Shown on the 'Create a new password' screen when the reset session/continuation token "
        "is no longer valid (e.g. the app was relaunched mid-journey) -- ADR-0027 \u00a75.",
        "Your session has expired. Start again from 'Reset your password'",
        "Mae'ch sesiwn wedi dod i ben. Dechreuwch eto o 'Ailosod eich cyfrinair' _(needs_review)_",
    ),
    "passwordReset.offline.title": (
        "Offline panel heading shown on Sign In / the password-reset journey while the device "
        "has no connectivity (AC18, ADR-0027 \u00a77).",
        "You are offline",
        "Rydych All-lein",
    ),
    "passwordReset.offline.message": (
        "Offline panel body message (AC18).",
        "Connect to the internet and try again.",
        "Cysylltwch \u00e2'r rhyngrwyd a rhowch gynnig arall arni.",
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
