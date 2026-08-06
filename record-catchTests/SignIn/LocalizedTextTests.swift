//
//  LocalizedTextTests.swift
//  record-catchTests
//
//  Verifies that `LocalizedText` renders copy carrying the correct language
//  identifier so VoiceOver pronounces per-part content in the right language
//  (WCAG 3.1.2 Language of Parts).
//

import XCTest
@testable import record_catch

@MainActor
final class LocalizedTextTests: XCTestCase {

    func test_attributedString_carriesEnglishLanguageIdentifier() {
        let attributed = LocalizedText.attributedString("Sign in", language: .english)

        XCTAssertEqual(String(attributed.characters), "Sign in")
        XCTAssertEqual(attributed.runs.first?.languageIdentifier, "en")
    }

    func test_attributedString_carriesWelshLanguageIdentifier() {
        let attributed = LocalizedText.attributedString("Mewngofnodi", language: .welsh)

        XCTAssertEqual(String(attributed.characters), "Mewngofnodi")
        XCTAssertEqual(attributed.runs.first?.languageIdentifier, "cy")
    }

    func test_attributedString_appliesLanguageAcrossWholeString() {
        let attributed = LocalizedText.attributedString(
            "Mae'r cyfeiriad e-bost neu'r cyfrinair a roddwyd gennych yn anghywir",
            language: .welsh
        )

        // A single run covering the whole string, all tagged Welsh.
        for run in attributed.runs {
            XCTAssertEqual(run.languageIdentifier, "cy")
        }
    }
}
