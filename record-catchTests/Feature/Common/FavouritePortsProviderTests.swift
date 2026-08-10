import XCTest
@testable import record_catch

final class FavouritePortsProviderTests: XCTestCase {

    func test_favouritePorts_initiallyEmpty() async throws {
        let sut = StubFavouritePortsProvider()

        let favourites = try await sut.favouritePorts()

        XCTAssertTrue(favourites.isEmpty)
    }

    func test_favouritePorts_returnsSeededFavouritesSortedByName() async throws {
        let sut = StubFavouritePortsProvider(initialFavourites: [PortOption(name: "Newlyn"), PortOption(name: "Aberdeen")])

        let favourites = try await sut.favouritePorts()

        XCTAssertEqual(favourites.map(\.name), ["Aberdeen", "Newlyn"])
    }

    func test_addFavourite_addsPort_andIsVisibleOnNextRead() async throws {
        let sut = StubFavouritePortsProvider()

        try await sut.addFavourite(PortOption(name: "Hastings"))

        let favourites = try await sut.favouritePorts()
        XCTAssertEqual(favourites.map(\.name), ["Hastings"])
    }

    func test_addFavourite_isIdempotent_forDuplicatePort() async throws {
        let sut = StubFavouritePortsProvider()

        try await sut.addFavourite(PortOption(name: "Hastings"))
        try await sut.addFavourite(PortOption(name: "Hastings"))

        let favourites = try await sut.favouritePorts()
        XCTAssertEqual(favourites.count, 1)
    }

    func test_favouritesAreNotScopedByVessel() async throws {
        // Per-user favourites (ADR-0004): the provider takes no vessel and returns the same list
        // regardless of the vessel context on screen.
        let sut = StubFavouritePortsProvider()
        try await sut.addFavourite(PortOption(name: "Hastings"))

        let favourites = try await sut.favouritePorts()

        XCTAssertEqual(favourites.map(\.name), ["Hastings"])
    }
}
