import XCTest
@testable import record_catch

/// Security-critical path — 100% coverage target (testing.instructions.md): `EntraConfiguration`
/// must never fall back to another tenant/backend if its values are missing or malformed
/// (ADR-0020 §3, ADR-0022 §6).
final class EntraConfigurationTests: XCTestCase {

    private struct StubBundle: InfoDictionaryProviding {
        let config: [String: Any]?

        func object(forInfoDictionaryKey key: String) -> Any? {
            guard key == "MMOCRAppConfig" else { return nil }
            return config
        }
    }

    private static let validClientID = "54911235-9884-41b9-ba69-8b44ac8e1a1d"

    func test_init_whenBothValuesValid_resolvesSuccessfully() throws {
        let bundle = StubBundle(config: [
            "ENTRA_CLIENT_ID": Self.validClientID,
            "ENTRA_TENANT_SUBDOMAIN": "contoso"
        ])

        let configuration = try EntraConfiguration(bundle: bundle)

        XCTAssertEqual(configuration.clientID, Self.validClientID)
        XCTAssertEqual(configuration.tenantSubdomain, "contoso")
    }

    func test_init_trimsWhitespaceFromBothValues() throws {
        let bundle = StubBundle(config: [
            "ENTRA_CLIENT_ID": "  \(Self.validClientID)  ",
            "ENTRA_TENANT_SUBDOMAIN": "  contoso  "
        ])

        let configuration = try EntraConfiguration(bundle: bundle)

        XCTAssertEqual(configuration.clientID, Self.validClientID)
        XCTAssertEqual(configuration.tenantSubdomain, "contoso")
    }

    func test_init_whenConfigDictionaryMissing_throwsNotConfigured() {
        let bundle = StubBundle(config: nil)

        XCTAssertThrowsError(try EntraConfiguration(bundle: bundle)) { error in
            XCTAssertEqual(error as? EntraConfigurationError, .notConfigured)
        }
    }

    func test_init_whenClientIDMissing_throwsNotConfigured() {
        let bundle = StubBundle(config: ["ENTRA_TENANT_SUBDOMAIN": "contoso"])

        XCTAssertThrowsError(try EntraConfiguration(bundle: bundle)) { error in
            XCTAssertEqual(error as? EntraConfigurationError, .notConfigured)
        }
    }

    func test_init_whenTenantSubdomainMissing_throwsNotConfigured() {
        let bundle = StubBundle(config: ["ENTRA_CLIENT_ID": Self.validClientID])

        XCTAssertThrowsError(try EntraConfiguration(bundle: bundle)) { error in
            XCTAssertEqual(error as? EntraConfigurationError, .notConfigured)
        }
    }

    func test_init_whenClientIDBlank_throwsNotConfigured() {
        let bundle = StubBundle(config: [
            "ENTRA_CLIENT_ID": "   ",
            "ENTRA_TENANT_SUBDOMAIN": "contoso"
        ])

        XCTAssertThrowsError(try EntraConfiguration(bundle: bundle)) { error in
            XCTAssertEqual(error as? EntraConfigurationError, .notConfigured)
        }
    }

    func test_init_whenClientIDNotGUIDShaped_throwsNotConfigured() {
        let bundle = StubBundle(config: [
            "ENTRA_CLIENT_ID": "not-a-guid",
            "ENTRA_TENANT_SUBDOMAIN": "contoso"
        ])

        XCTAssertThrowsError(try EntraConfiguration(bundle: bundle)) { error in
            XCTAssertEqual(error as? EntraConfigurationError, .notConfigured)
        }
    }

    func test_init_whenTenantSubdomainBlank_throwsNotConfigured() {
        let bundle = StubBundle(config: [
            "ENTRA_CLIENT_ID": Self.validClientID,
            "ENTRA_TENANT_SUBDOMAIN": "   "
        ])

        XCTAssertThrowsError(try EntraConfiguration(bundle: bundle)) { error in
            XCTAssertEqual(error as? EntraConfigurationError, .notConfigured)
        }
    }

    func test_init_whenTenantSubdomainContainsInvalidCharacters_throwsNotConfigured() {
        let bundle = StubBundle(config: [
            "ENTRA_CLIENT_ID": Self.validClientID,
            "ENTRA_TENANT_SUBDOMAIN": "contoso.ciamlogin.com"
        ])

        XCTAssertThrowsError(try EntraConfiguration(bundle: bundle)) { error in
            XCTAssertEqual(error as? EntraConfigurationError, .notConfigured)
        }
    }

    // MARK: - Pure shape checks

    func test_isGUIDShaped_withValidGUID_returnsTrue() {
        XCTAssertTrue(EntraConfiguration.isGUIDShaped(Self.validClientID))
    }

    func test_isGUIDShaped_withInvalidString_returnsFalse() {
        XCTAssertFalse(EntraConfiguration.isGUIDShaped("not-a-guid"))
    }

    func test_isValidSubdomain_withLettersDigitsHyphens_returnsTrue() {
        XCTAssertTrue(EntraConfiguration.isValidSubdomain("contoso-external-01"))
    }

    func test_isValidSubdomain_whenEmpty_returnsFalse() {
        XCTAssertFalse(EntraConfiguration.isValidSubdomain(""))
    }

    func test_isValidSubdomain_withDot_returnsFalse() {
        XCTAssertFalse(EntraConfiguration.isValidSubdomain("contoso.ciamlogin"))
    }
}
