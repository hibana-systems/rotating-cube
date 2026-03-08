import XCTest
@testable import RotatingCubeCore

final class SceneGeometryTests: XCTestCase {
    func testCubeEdgesRemainTwelveSegments() {
        let primitives = SceneGeometryBuilder.buildCube(spec: .defaultWallpaper, time: 0)

        XCTAssertEqual(primitives.count, 12)
    }

    func testGridLineCountMatchesExtentFormula() {
        let spec = SceneSpec.defaultWallpaper
        let primitives = SceneGeometryBuilder.buildGrid(spec: spec)
        let expectedLineCount = (spec.grid.extent * 2 + 1) * 2

        XCTAssertEqual(primitives.count, expectedLineCount)
    }

    func testCubeAnimationLoopsBackToItsInitialFrame() {
        let spec = SceneSpec.defaultWallpaper
        let start = SceneGeometryBuilder.buildCube(spec: spec, time: 0)
        let loop = SceneGeometryBuilder.buildCube(spec: spec, time: spec.loop.durationSeconds)

        XCTAssertEqual(start, loop)
    }

    func testCubeUsesContinuousEndpointColorVariation() {
        let primitives = SceneGeometryBuilder.buildCube(spec: .defaultWallpaper, time: 0)
        let hasGradientEdge = primitives.contains { primitive in
            primitive.coreStartColor != primitive.coreEndColor
        }

        XCTAssertTrue(hasGradientEdge)
    }
}
