import XCTest
@testable import record_catch

final class PointInPolygonTests: XCTestCase {

    private let square: [CGPoint] = [
        CGPoint(x: 0, y: 0),
        CGPoint(x: 10, y: 0),
        CGPoint(x: 10, y: 10),
        CGPoint(x: 0, y: 10)
    ]

    func testPointInsideSquareReturnsTrue() {
        XCTAssertTrue(PointInPolygon.contains(CGPoint(x: 5, y: 5), ring: square))
    }

    func testPointOutsideSquareReturnsFalse() {
        XCTAssertFalse(PointInPolygon.contains(CGPoint(x: 15, y: 5), ring: square))
        XCTAssertFalse(PointInPolygon.contains(CGPoint(x: -5, y: 5), ring: square))
        XCTAssertFalse(PointInPolygon.contains(CGPoint(x: 5, y: 15), ring: square))
    }

    func testPointsJustOutsideEachEdgeAreFalse() {
        XCTAssertFalse(PointInPolygon.contains(CGPoint(x: 5, y: -0.01), ring: square))
        XCTAssertFalse(PointInPolygon.contains(CGPoint(x: 5, y: 10.01), ring: square))
        XCTAssertFalse(PointInPolygon.contains(CGPoint(x: -0.01, y: 5), ring: square))
        XCTAssertFalse(PointInPolygon.contains(CGPoint(x: 10.01, y: 5), ring: square))
    }

    func testDegenerateRingReturnsFalse() {
        XCTAssertFalse(PointInPolygon.contains(CGPoint(x: 0, y: 0), ring: []))
        XCTAssertFalse(
            PointInPolygon.contains(
                CGPoint(x: 0, y: 0),
                ring: [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 1)]
            )
        )
    }

    func testAdjacentGridSquaresDoNotOverlap() {
        // A grid neighbour sharing the right edge (x = 10) of `square`,
        // mirroring how the real subzone grid tiles rectangles edge-to-edge.
        let neighbour: [CGPoint] = [
            CGPoint(x: 10, y: 0),
            CGPoint(x: 20, y: 0),
            CGPoint(x: 20, y: 10),
            CGPoint(x: 10, y: 10)
        ]

        let pointJustInsideNeighbour = CGPoint(x: 10.5, y: 5)

        XCTAssertTrue(PointInPolygon.contains(pointJustInsideNeighbour, ring: neighbour))
        XCTAssertFalse(PointInPolygon.contains(pointJustInsideNeighbour, ring: square))
    }
}
