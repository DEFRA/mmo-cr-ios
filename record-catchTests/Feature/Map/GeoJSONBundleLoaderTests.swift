import XCTest
@testable import record_catch

final class GeoJSONBundleLoaderTests: XCTestCase {

    func testLoadsDataForExistingBundledResource() throws {
        let testBundle = Bundle(for: GeoJSONBundleLoaderTests.self)

        let data = try GeoJSONBundleLoader.loadData(resource: "map", bundle: testBundle)

        XCTAssertFalse(data.isEmpty)
    }

    func testThrowsResourceNotFoundForMissingResource() {
        let testBundle = Bundle(for: GeoJSONBundleLoaderTests.self)

        XCTAssertThrowsError(
            try GeoJSONBundleLoader.loadData(resource: "does-not-exist", bundle: testBundle)
        ) { error in
            XCTAssertEqual(error as? OfflineMapDataError, .resourceNotFound("does-not-exist"))
        }
    }
}
