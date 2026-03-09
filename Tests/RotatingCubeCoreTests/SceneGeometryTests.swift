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

    func testDefaultWallpaperProjectsFloorWithinCubeVerticalSpan() {
        let spec = SceneSpec.defaultWallpaper
        let aspectRatio = Float(spec.output.width) / Float(spec.output.height)
        let cubeTop = MatrixMath.projectToNormalizedDeviceCoordinates(
            point: SIMD3<Float>(0, spec.cube.center.y + (spec.cube.size / 2), 0),
            camera: spec.camera,
            aspectRatio: aspectRatio
        )
        let cubeBottom = MatrixMath.projectToNormalizedDeviceCoordinates(
            point: SIMD3<Float>(0, spec.cube.center.y - (spec.cube.size / 2), 0),
            camera: spec.camera,
            aspectRatio: aspectRatio
        )
        let gridPoints = SceneGeometryBuilder.buildGrid(spec: spec)
            .flatMap { [$0.start, $0.end] }
        let projectedGridPoints = gridPoints.compactMap { point in
            MatrixMath.projectToNormalizedDeviceCoordinates(
                point: point,
                camera: spec.camera,
                aspectRatio: aspectRatio
            )
        }
        let visibleGridScreenY = projectedGridPoints
            .map { ($0.y + 1) * 0.5 }
            .filter { $0 >= 0 && $0 <= 1 }
        let gridTop = visibleGridScreenY.min()

        XCTAssertNotNil(cubeTop)
        XCTAssertNotNil(cubeBottom)
        XCTAssertNotNil(gridTop)

        let cubeTopScreenY = (cubeTop!.y + 1) * 0.5
        let cubeBottomScreenY = (cubeBottom!.y + 1) * 0.5

        XCTAssertGreaterThan(gridTop!, cubeTopScreenY)
        XCTAssertLessThan(gridTop!, cubeBottomScreenY)
    }

    func testDefaultWallpaperCameraUsesUprightOrientation() {
        XCTAssertEqual(SceneSpec.defaultWallpaper.camera.upVector, SIMD3<Float>(0, -1, 0))
    }

    func testDefaultWallpaperUsesBaselineCameraPreset() {
        XCTAssertEqual(SceneSpec.defaultWallpaper.camera, SceneSpec.baselineWallpaperCamera)
    }

    func testDefaultWallpaperGridExtendsPastViewportSides() {
        let spec = SceneSpec.defaultWallpaper
        let aspectRatio = Float(spec.output.width) / Float(spec.output.height)
        let limit = Float(spec.grid.extent) * spec.grid.spacing
        let farLeftCorner = MatrixMath.projectToNormalizedDeviceCoordinates(
            point: SIMD3<Float>(-limit, spec.grid.y, -limit),
            camera: spec.camera,
            aspectRatio: aspectRatio
        )
        let farRightCorner = MatrixMath.projectToNormalizedDeviceCoordinates(
            point: SIMD3<Float>(limit, spec.grid.y, -limit),
            camera: spec.camera,
            aspectRatio: aspectRatio
        )

        XCTAssertNotNil(farLeftCorner)
        XCTAssertNotNil(farRightCorner)
        XCTAssertGreaterThan(abs(farLeftCorner!.x), 1.0)
        XCTAssertGreaterThan(abs(farRightCorner!.x), 1.0)
    }

    func testCameraPitchChangesProjectedScreenPosition() {
        var pitchedCamera = SceneSpec.defaultWallpaper.camera
        pitchedCamera.pitchDegrees = 45

        var neutralCamera = pitchedCamera
        neutralCamera.pitchDegrees = 0

        let aspectRatio = Float(SceneSpec.defaultWallpaper.output.width)
            / Float(SceneSpec.defaultWallpaper.output.height)
        let samplePoint = SIMD3<Float>(0, SceneSpec.defaultWallpaper.grid.y, -6)

        let pitchedProjection = MatrixMath.projectToNormalizedDeviceCoordinates(
            point: samplePoint,
            camera: pitchedCamera,
            aspectRatio: aspectRatio
        )
        let neutralProjection = MatrixMath.projectToNormalizedDeviceCoordinates(
            point: samplePoint,
            camera: neutralCamera,
            aspectRatio: aspectRatio
        )

        XCTAssertNotNil(pitchedProjection)
        XCTAssertNotNil(neutralProjection)
        XCTAssertNotEqual(pitchedProjection!.y, neutralProjection!.y, accuracy: 0.0001)
    }
}
