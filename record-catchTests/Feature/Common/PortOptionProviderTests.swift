import XCTest
@testable import record_catch

final class PortOptionProviderTests: XCTestCase {

    func testStubProviderReturnsExpectedOrderedOptions() {
        let provider = StubPortOptionProvider()

        XCTAssertEqual(
            provider.options,
            [
                "Aberdeen",
                "Brixham",
                "Grimsby",
                "Hull",
                "Lerwick",
                "Milford Haven",
                "Newlyn",
                "Peterhead",
                "Plymouth",
                "Scrabster",
                "Shoreham",
                "Whitby"
            ]
        )
    }

    func testStubProviderDoesNotContainDuplicates() {
        let provider = StubPortOptionProvider()

        XCTAssertEqual(Set(provider.options).count, provider.options.count)
    }
}
