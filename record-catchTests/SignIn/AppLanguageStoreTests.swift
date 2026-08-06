import XCTest
@testable import record_catch

@MainActor
final class AppLanguageStoreTests: XCTestCase {

    private func makeDefaults() -> UserDefaults {
        let suite = "test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    func test_default_isEnglish() {
        let sut = AppLanguageStore(defaults: makeDefaults())
        XCTAssertEqual(sut.language, .english)
    }

    func test_toggle_switchesEnglishToWelsh_andBack() {
        let sut = AppLanguageStore(defaults: makeDefaults())

        sut.toggle()
        XCTAssertEqual(sut.language, .welsh)

        sut.toggle()
        XCTAssertEqual(sut.language, .english)
    }

    func test_selection_persistsAcrossInstances() {
        let defaults = makeDefaults()
        let first = AppLanguageStore(defaults: defaults)
        first.language = .welsh

        let second = AppLanguageStore(defaults: defaults)
        XCTAssertEqual(second.language, .welsh)
    }

    func test_appLanguage_oppositeAndLocale() {
        XCTAssertEqual(AppLanguage.english.opposite, .welsh)
        XCTAssertEqual(AppLanguage.welsh.opposite, .english)
        XCTAssertEqual(AppLanguage.welsh.locale.identifier, "cy")
    }

    func test_localized_resolvesKnownKey() {
        let sut = AppLanguageStore(defaults: makeDefaults())
        // English catalog value for the sign-in button.
        XCTAssertEqual(sut.localized("signIn.button"), "Sign in")

        sut.toggle() // Welsh
        XCTAssertEqual(sut.localized("signIn.button"), "Mewngofnodi")
    }
}
