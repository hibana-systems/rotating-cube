import XCTest
@testable import RotatingCubeKit

final class WireframeGeometryBuilderTests: XCTestCase {
    func testCubeSegmentsProduceTwelveEdges() {
        let segments = WireframeGeometryBuilder.cubeSegments(
            size: 4,
            center: SIMD3<Double>(0, 0, 0)
        )

        XCTAssertEqual(segments.count, 12)
    }

    func testCubeVerticesAreCenteredAroundInputOrigin() {
        let center = SIMD3<Double>(1.5, 2.5, -0.5)
        let vertices = WireframeGeometryBuilder.cubeVertices(size: 2, center: center)

        XCTAssertEqual(vertices.count, 8)
        XCTAssertEqual(vertices.map(\.x).min(), 0.5)
        XCTAssertEqual(vertices.map(\.x).max(), 2.5)
        XCTAssertEqual(vertices.map(\.y).min(), 1.5)
        XCTAssertEqual(vertices.map(\.y).max(), 3.5)
        XCTAssertEqual(vertices.map(\.z).min(), -1.5)
        XCTAssertEqual(vertices.map(\.z).max(), 0.5)
    }

    func testGridSegmentsCoverExpectedLineCountAndBounds() {
        let segments = WireframeGeometryBuilder.gridSegments(extent: 2, spacing: 1.5, y: -0.25)

        XCTAssertEqual(segments.count, 10)
        XCTAssertEqual(segments.first?.start, SIMD3<Double>(-3.0, -0.25, -3.0))
        XCTAssertEqual(segments.first?.end, SIMD3<Double>(3.0, -0.25, -3.0))
        XCTAssertEqual(segments.last?.start, SIMD3<Double>(3.0, -0.25, -3.0))
        XCTAssertEqual(segments.last?.end, SIMD3<Double>(3.0, -0.25, 3.0))
    }
}
