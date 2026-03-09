import Foundation
import simd

enum CRTSampling {
    static func warpedSampleUV(
        uv: SIMD2<Float>,
        resolution: SIMD2<Float>,
        crt: CRTSettings
    ) -> SIMD2<Float> {
        let centered = uv * 2 - SIMD2<Float>(repeating: 1)
        let overscannedCentered: SIMD2<Float>

        switch crt.edgeFillMode {
        case .crop:
            overscannedCentered = SIMD2<Float>(
                centered.x / max(crt.overscanScaleX, 0.0001),
                centered.y / max(crt.overscanScaleY, 0.0001)
            )
        case .stretch:
            overscannedCentered = centered
        }

        let aspect = max(resolution.x / max(resolution.y, 1), 0.0001)
        var aspectCentered = SIMD2<Float>(overscannedCentered.x * aspect, overscannedCentered.y)
        let radiusSquared = simd_dot(aspectCentered, aspectCentered)
        let radialWarp = 1 + crt.barrelDistortion * radiusSquared
        let cornerWeight = smoothstep(edge0: 0.15, edge1: 1.0, x: radiusSquared)

        aspectCentered *= radialWarp
        aspectCentered -= SIMD2<Float>(
            aspectCentered.x * abs(aspectCentered.y),
            aspectCentered.y * abs(aspectCentered.x)
        ) * crt.cornerPinch * cornerWeight

        let warped = SIMD2<Float>(aspectCentered.x / aspect, aspectCentered.y)
        return warped * 0.5 + SIMD2<Float>(repeating: 0.5)
    }

    static func resolvedSampleUV(
        uv: SIMD2<Float>,
        resolution: SIMD2<Float>,
        crt: CRTSettings
    ) -> SIMD2<Float> {
        clamp(
            warpedSampleUV(uv: uv, resolution: resolution, crt: crt),
            min: SIMD2<Float>(repeating: 0),
            max: SIMD2<Float>(repeating: 1)
        )
    }

    private static func smoothstep(edge0: Float, edge1: Float, x: Float) -> Float {
        let t = clamp((x - edge0) / max(edge1 - edge0, 0.0001), min: 0, max: 1)
        return t * t * (3 - 2 * t)
    }

    private static func clamp(_ value: Float, min minValue: Float, max maxValue: Float) -> Float {
        Swift.max(minValue, Swift.min(maxValue, value))
    }

    private static func clamp(
        _ value: SIMD2<Float>,
        min minValue: SIMD2<Float>,
        max maxValue: SIMD2<Float>
    ) -> SIMD2<Float> {
        SIMD2<Float>(
            clamp(value.x, min: minValue.x, max: maxValue.x),
            clamp(value.y, min: minValue.y, max: maxValue.y)
        )
    }
}
