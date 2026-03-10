import XCTest
@testable import RotatingCubeCore

final class CRTSamplingTests: XCTestCase {
    func testDefaultWallpaperCropOverscanKeepsHorizontalEdgeSamplesInBounds() {
        let spec = SceneSpec.defaultWallpaper
        let resolution = SIMD2<Float>(
            Float(spec.output.width),
            Float(spec.output.height)
        )

        let leftSample = CRTSampling.warpedSampleUV(
            uv: SIMD2<Float>(0.0, 0.8),
            resolution: resolution,
            crt: spec.crt
        )
        let rightSample = CRTSampling.warpedSampleUV(
            uv: SIMD2<Float>(1.0, 0.8),
            resolution: resolution,
            crt: spec.crt
        )

        XCTAssertGreaterThanOrEqual(leftSample.x, 0.0)
        XCTAssertLessThanOrEqual(leftSample.x, 1.0)
        XCTAssertGreaterThanOrEqual(rightSample.x, 0.0)
        XCTAssertLessThanOrEqual(rightSample.x, 1.0)
    }

    func testStretchModeClampsOutOfBoundsSamples() {
        var crt = SceneSpec.defaultWallpaper.crt
        crt.edgeFillMode = .stretch
        crt.barrelDistortion = 0.2

        let resolution = SIMD2<Float>(
            Float(SceneSpec.defaultWallpaper.output.width),
            Float(SceneSpec.defaultWallpaper.output.height)
        )
        let rawSample = CRTSampling.warpedSampleUV(
            uv: SIMD2<Float>(1.0, 1.0),
            resolution: resolution,
            crt: crt
        )
        let resolvedSample = CRTSampling.resolvedSampleUV(
            uv: SIMD2<Float>(1.0, 1.0),
            resolution: resolution,
            crt: crt
        )

        XCTAssertTrue(
            rawSample.x > 1.0 || rawSample.y > 1.0 || rawSample.x < 0.0 || rawSample.y < 0.0
        )
        XCTAssertGreaterThanOrEqual(resolvedSample.x, 0.0)
        XCTAssertLessThanOrEqual(resolvedSample.x, 1.0)
        XCTAssertGreaterThanOrEqual(resolvedSample.y, 0.0)
        XCTAssertLessThanOrEqual(resolvedSample.y, 1.0)
    }

    func testBlurOffsetsScaleLinearlyWithRadius() {
        let texelSize = SIMD2<Float>(0.5, 0.25)
        let unitOffsets = BloomSampling.blurOffsets(
            direction: SIMD2<Float>(1, 0),
            texelSize: texelSize,
            radius: 1.0
        )
        let wideOffsets = BloomSampling.blurOffsets(
            direction: SIMD2<Float>(1, 0),
            texelSize: texelSize,
            radius: 2.4
        )

        XCTAssertEqual(unitOffsets.count, BloomSampling.blurTapCount)
        XCTAssertEqual(wideOffsets.count, BloomSampling.blurTapCount)
        XCTAssertEqual(wideOffsets[0].x, unitOffsets[0].x * 2.4, accuracy: 0.0001)
        XCTAssertEqual(wideOffsets[3].x, unitOffsets[3].x * 2.4, accuracy: 0.0001)
        XCTAssertEqual(wideOffsets[0].y, 0, accuracy: 0.0001)
    }

    func testBlurOffsetsClampNegativeRadiusToZero() {
        let offsets = BloomSampling.blurOffsets(
            direction: SIMD2<Float>(0, 2),
            texelSize: SIMD2<Float>(0.5, 0.25),
            radius: -3.0
        )

        XCTAssertEqual(offsets, Array(repeating: SIMD2<Float>(repeating: 0), count: BloomSampling.blurTapCount))
    }
}
