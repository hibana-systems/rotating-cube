import XCTest
import simd
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

    func testDefaultWallpaperCubeContainsHDREmissiveEnergy() {
        let primitives = SceneGeometryBuilder.buildCube(spec: .defaultWallpaper, time: 0)
        let maxChannel = primitives
            .flatMap { primitive in
                [
                    primitive.coreStartColor,
                    primitive.coreEndColor,
                    primitive.glowStartColor,
                    primitive.glowEndColor,
                ]
            }
            .map(maxRGBChannel)
            .max() ?? 0

        XCTAssertGreaterThan(maxChannel, 1.0)
    }

    func testCubeDepthHierarchyBoostsNearerEdges() {
        var spec = SceneSpec.defaultWallpaper
        let white = RGBAColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        spec.palette.cubeCornerColors = Array(repeating: white, count: 8)

        let primitives = SceneGeometryBuilder.buildCube(spec: spec, time: 0)
        let sortedByDepth = primitives.sorted {
            midpointDepth(of: $0, camera: spec.camera) < midpointDepth(of: $1, camera: spec.camera)
        }

        XCTAssertGreaterThan(rgbEnergy(sortedByDepth.first!.coreStartColor), rgbEnergy(sortedByDepth.last!.coreStartColor))
        XCTAssertGreaterThan(rgbEnergy(sortedByDepth.first!.glowStartColor), rgbEnergy(sortedByDepth.last!.glowStartColor))
    }

    func testCubeDepthNormalizationFallsBackToNeutralWhenRangeIsTiny() {
        let weights = SceneGeometryBuilder.normalizedDepthWeights(
            for: [9.0, 9.00001, 9.00002]
        )

        XCTAssertNil(weights)
    }

    func testGridDistanceFalloffDimsFartherRows() {
        let spec = normalizedGridSpec()
        let primitives = SceneGeometryBuilder.buildGrid(spec: spec)
        let limit = Float(spec.grid.extent) * spec.grid.spacing
        let nearRow = primitives.first {
            abs($0.start.z) < 0.0001 && abs($0.end.z) < 0.0001 && $0.start.x != $0.end.x
        }
        let farRow = primitives.first {
            abs($0.start.z + limit) < 0.0001 && abs($0.end.z + limit) < 0.0001 && $0.start.x != $0.end.x
        }

        XCTAssertNotNil(nearRow)
        XCTAssertNotNil(farRow)
        XCTAssertGreaterThan(nearRow!.coreStartColor.x, farRow!.coreStartColor.x)
        XCTAssertGreaterThan(nearRow!.glowStartColor.x, farRow!.glowStartColor.x)
    }

    func testGridDepthFalloffCreatesAlongLineGradient() {
        let spec = normalizedGridSpec()
        let primitives = SceneGeometryBuilder.buildGrid(spec: spec)
        let centerColumn = primitives.first {
            abs($0.start.x) < 0.0001 && abs($0.end.x) < 0.0001 && $0.start.z != $0.end.z
        }

        XCTAssertNotNil(centerColumn)
        XCTAssertLessThan(centerColumn!.coreStartColor.x, centerColumn!.coreEndColor.x)
        XCTAssertLessThan(centerColumn!.glowStartColor.x, centerColumn!.glowEndColor.x)
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
        let projectedGridScreenY = projectedGridPoints.map { projectedPoint in
            (projectedPoint.y + 1) * 0.5
        }
        let visibleGridScreenY = projectedGridScreenY.filter { screenY in
            screenY >= 0 && screenY <= 1
        }
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

    private func normalizedGridSpec() -> SceneSpec {
        var spec = SceneSpec.defaultWallpaper
        spec.palette.gridCore = RGBAColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        spec.palette.gridGlow = RGBAColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        spec.grid.lineStyle = LineStyle(
            coreWidthPixels: spec.grid.lineStyle.coreWidthPixels,
            glowWidthPixels: spec.grid.lineStyle.glowWidthPixels,
            coreOpacity: 1.0,
            glowOpacity: 1.0,
            coreIntensity: 1.0,
            glowIntensity: 1.0
        )
        return spec
    }

    private func midpointDepth(of primitive: LinePrimitive, camera: CameraSettings) -> Float {
        let midpoint = (primitive.start + primitive.end) * 0.5
        let forward = MatrixMath.effectiveTarget(for: camera) - camera.position
        let normalizedForward = simd_normalize(forward)
        return simd_dot(midpoint - camera.position, normalizedForward)
    }

    private func rgbEnergy(_ color: SIMD4<Float>) -> Float {
        color.x + color.y + color.z
    }

    private func maxRGBChannel(_ color: SIMD4<Float>) -> Float {
        max(color.x, max(color.y, color.z))
    }
}
