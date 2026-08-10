import XCTest
@testable import record_catch

final class PortSearchProviderTests: XCTestCase {

    func test_searchPorts_belowMinimumCharacters_returnsEmpty() async throws {
        let sut = StubPortSearchProvider(minimumCharacters: 2)

        let results = try await sut.searchPorts(matching: "a")

        XCTAssertTrue(results.isEmpty)
    }

    func test_searchPorts_matchesCaseInsensitively() async throws {
        let sut = StubPortSearchProvider()

        let results = try await sut.searchPorts(matching: "aber")

        XCTAssertEqual(results.map(\.name), ["Aberdeen"])
    }

    func test_searchPorts_returnsAllMatches() async throws {
        let sut = StubPortSearchProvider()

        let results = try await sut.searchPorts(matching: "ham")

        XCTAssertEqual(results.map(\.name), ["Brixham", "Shoreham"])
    }

    func test_searchPorts_trimsWhitespace() async throws {
        let sut = StubPortSearchProvider()

        let results = try await sut.searchPorts(matching: "  aber  ")

        XCTAssertEqual(results.map(\.name), ["Aberdeen"])
    }

    func test_allPorts_returnsFullStubList() async throws {
        let sut = StubPortSearchProvider(names: ["Hull", "Newlyn"])

        let results = try await sut.allPorts()

        XCTAssertEqual(results.map(\.name), ["Hull", "Newlyn"])
    }

    func test_filtered_isPureAndDeterministic() {
        let ports = [PortOption(name: "Hull"), PortOption(name: "Newlyn")]

        XCTAssertEqual(
            StubPortSearchProvider.filtered(query: "ne", minimumCharacters: 2, ports: ports).map(\.name),
            ["Newlyn"]
        )
        XCTAssertTrue(
            StubPortSearchProvider.filtered(query: "n", minimumCharacters: 2, ports: ports).isEmpty
        )
    }
}
