import Foundation
import simd

public struct LineSegment: Sendable, Equatable {
    public var start: SIMD3<Float>
    public var end: SIMD3<Float>

    public init(start: SIMD3<Float>, end: SIMD3<Float>) {
        self.start = start
        self.end = end
    }
}

public struct LinePrimitive: Sendable, Equatable {
    public var start: SIMD3<Float>
    public var end: SIMD3<Float>
    public var coreStartColor: SIMD4<Float>
    public var coreEndColor: SIMD4<Float>
    public var glowStartColor: SIMD4<Float>
    public var glowEndColor: SIMD4<Float>
    public var coreWidthPixels: Float
    public var glowWidthPixels: Float

    public init(
        start: SIMD3<Float>,
        end: SIMD3<Float>,
        coreStartColor: SIMD4<Float>,
        coreEndColor: SIMD4<Float>,
        glowStartColor: SIMD4<Float>,
        glowEndColor: SIMD4<Float>,
        coreWidthPixels: Float,
        glowWidthPixels: Float
    ) {
        self.start = start
        self.end = end
        self.coreStartColor = coreStartColor
        self.coreEndColor = coreEndColor
        self.glowStartColor = glowStartColor
        self.glowEndColor = glowEndColor
        self.coreWidthPixels = coreWidthPixels
        self.glowWidthPixels = glowWidthPixels
    }
}

public enum SceneGeometryBuilder {
    public static let cubeEdgeIndices: [(Int, Int)] = [
        (0, 1), (1, 2), (2, 3), (3, 0),
        (4, 5), (5, 6), (6, 7), (7, 4),
        (0, 4), (1, 5), (2, 6), (3, 7),
    ]

    public static func cubeVertices(size: Float) -> [SIMD3<Float>] {
        let half = size / 2
        return [
            SIMD3<Float>(-half, -half, -half),
            SIMD3<Float>(half, -half, -half),
            SIMD3<Float>(half, half, -half),
            SIMD3<Float>(-half, half, -half),
            SIMD3<Float>(-half, -half, half),
            SIMD3<Float>(half, -half, half),
            SIMD3<Float>(half, half, half),
            SIMD3<Float>(-half, half, half),
        ]
    }

    public static func buildLinePrimitives(
        spec: SceneSpec,
        time: Double
    ) -> [LinePrimitive] {
        buildGrid(spec: spec) + buildCube(spec: spec, time: time)
    }

    public static func buildCube(spec: SceneSpec, time: Double) -> [LinePrimitive] {
        let state = cubeState(spec: spec, time: time)
        let midpointDepths = cubeEdgeIndices.map { startIndex, endIndex in
            let midpoint = (state.worldVertices[startIndex] + state.worldVertices[endIndex]) * 0.5
            return forwardDepth(for: midpoint, camera: spec.camera)
        }
        let normalizedDepths = normalizedDepthWeights(for: midpointDepths)

        return cubeEdgeIndices.enumerated().map { index, edge in
            let (startIndex, endIndex) = edge
            let startLocal = state.localVertices[startIndex]
            let endLocal = state.localVertices[endIndex]
            let startColor = spectralColor(
                for: startLocal,
                cubeSize: spec.cube.size,
                palette: spec.palette.cubeCornerColors
            )
            let endColor = spectralColor(
                for: endLocal,
                cubeSize: spec.cube.size,
                palette: spec.palette.cubeCornerColors
            )
            let coreScale: Float
            let glowScale: Float

            if let normalizedDepths {
                coreScale = mix(
                    spec.cube.depthHierarchy.farCoreScale,
                    spec.cube.depthHierarchy.nearCoreScale,
                    t: normalizedDepths[index]
                )
                glowScale = mix(
                    spec.cube.depthHierarchy.farGlowScale,
                    spec.cube.depthHierarchy.nearGlowScale,
                    t: normalizedDepths[index]
                )
            } else {
                coreScale = 1.0
                glowScale = 1.0
            }

            return LinePrimitive(
                start: state.worldVertices[startIndex],
                end: state.worldVertices[endIndex],
                coreStartColor: applyStyle(
                    startColor,
                    intensity: spec.cube.lineStyle.coreIntensity * coreScale,
                    opacity: spec.cube.lineStyle.coreOpacity
                ),
                coreEndColor: applyStyle(
                    endColor,
                    intensity: spec.cube.lineStyle.coreIntensity * coreScale,
                    opacity: spec.cube.lineStyle.coreOpacity
                ),
                glowStartColor: applyStyle(
                    glowColor(from: startColor),
                    intensity: spec.cube.lineStyle.glowIntensity * glowScale,
                    opacity: spec.cube.lineStyle.glowOpacity
                ),
                glowEndColor: applyStyle(
                    glowColor(from: endColor),
                    intensity: spec.cube.lineStyle.glowIntensity * glowScale,
                    opacity: spec.cube.lineStyle.glowOpacity
                ),
                coreWidthPixels: spec.cube.lineStyle.coreWidthPixels,
                glowWidthPixels: spec.cube.lineStyle.glowWidthPixels
            )
        }
    }

    public static func buildGrid(spec: SceneSpec) -> [LinePrimitive] {
        let gridColor = spec.palette.gridCore.simd
        let gridGlow = spec.palette.gridGlow.simd
        let limit = Float(spec.grid.extent) * spec.grid.spacing
        let offsets = (-spec.grid.extent...spec.grid.extent).map { Float($0) * spec.grid.spacing }
        let coreStyle = spec.grid.lineStyle
        let glowStyle = spec.grid.lineStyle

        func coreColor(at point: SIMD3<Float>) -> SIMD4<Float> {
            let scale = gridDepthScale(
                for: point,
                camera: spec.camera,
                falloff: spec.grid.distanceFalloff,
                minimumScale: spec.grid.distanceFalloff.minimumCoreScale
            )
            return applyStyle(
                gridColor,
                intensity: coreStyle.coreIntensity * scale,
                opacity: coreStyle.coreOpacity
            )
        }

        func glowColor(at point: SIMD3<Float>) -> SIMD4<Float> {
            let scale = gridDepthScale(
                for: point,
                camera: spec.camera,
                falloff: spec.grid.distanceFalloff,
                minimumScale: spec.grid.distanceFalloff.minimumGlowScale
            )
            return applyStyle(
                gridGlow,
                intensity: glowStyle.glowIntensity * scale,
                opacity: glowStyle.glowOpacity
            )
        }

        return offsets.flatMap { offset -> [LinePrimitive] in
            let rowStart = SIMD3<Float>(-limit, spec.grid.y, offset)
            let rowEnd = SIMD3<Float>(limit, spec.grid.y, offset)
            let columnStart = SIMD3<Float>(offset, spec.grid.y, -limit)
            let columnEnd = SIMD3<Float>(offset, spec.grid.y, limit)

            return [
                LinePrimitive(
                    start: rowStart,
                    end: rowEnd,
                    coreStartColor: coreColor(at: rowStart),
                    coreEndColor: coreColor(at: rowEnd),
                    glowStartColor: glowColor(at: rowStart),
                    glowEndColor: glowColor(at: rowEnd),
                    coreWidthPixels: spec.grid.lineStyle.coreWidthPixels,
                    glowWidthPixels: spec.grid.lineStyle.glowWidthPixels
                ),
                LinePrimitive(
                    start: columnStart,
                    end: columnEnd,
                    coreStartColor: coreColor(at: columnStart),
                    coreEndColor: coreColor(at: columnEnd),
                    glowStartColor: glowColor(at: columnStart),
                    glowEndColor: glowColor(at: columnEnd),
                    coreWidthPixels: spec.grid.lineStyle.coreWidthPixels,
                    glowWidthPixels: spec.grid.lineStyle.glowWidthPixels
                ),
            ]
        }
    }

    private static func cubeState(spec: SceneSpec, time: Double) -> (
        localVertices: [SIMD3<Float>],
        worldVertices: [SIMD3<Float>]
    ) {
        let wrappedTime = wrappedLoopTime(time, duration: spec.loop.durationSeconds)
        let loopProgress = Float(wrappedTime / spec.loop.durationSeconds)
        let xAngle = (spec.cube.xTiltDegrees * (.pi / 180))
            + (2 * .pi * Float(spec.cube.xRevolutionsPerLoop) * loopProgress)
        let yAngle = (spec.cube.initialYawDegrees * (.pi / 180))
            + (2 * .pi * Float(spec.cube.yRevolutionsPerLoop) * loopProgress)
        let rotation = MatrixMath.rotationY(yAngle) * MatrixMath.rotationX(xAngle)
        let localVertices = cubeVertices(size: spec.cube.size)
        let worldVertices = localVertices.map { (rotation * $0) + spec.cube.center }
        return (localVertices, worldVertices)
    }

    private static func spectralColor(
        for point: SIMD3<Float>,
        cubeSize: Float,
        palette: [RGBAColor]
    ) -> SIMD4<Float> {
        let half = cubeSize / 2
        let u = clamp((point.x + half) / cubeSize)
        let v = clamp((point.y + half) / cubeSize)
        let w = clamp((point.z + half) / cubeSize)

        let c00 = mix(palette[0].simd, palette[1].simd, t: u)
        let c10 = mix(palette[3].simd, palette[2].simd, t: u)
        let c01 = mix(palette[4].simd, palette[5].simd, t: u)
        let c11 = mix(palette[7].simd, palette[6].simd, t: u)
        let c0 = mix(c00, c10, t: v)
        let c1 = mix(c01, c11, t: v)

        return mix(c0, c1, t: w)
    }

    private static func glowColor(from color: SIMD4<Float>) -> SIMD4<Float> {
        SIMD4<Float>(
            min(color.x * 1.05 + 0.02, 1.0),
            min(color.y * 1.05 + 0.02, 1.0),
            min(color.z * 1.05 + 0.02, 1.0),
            1.0
        )
    }

    static func normalizedDepthWeights(
        for depths: [Float],
        epsilon: Float = 0.0001
    ) -> [Float]? {
        guard
            let minDepth = depths.min(),
            let maxDepth = depths.max()
        else {
            return []
        }

        let range = maxDepth - minDepth
        guard range > epsilon else {
            return nil
        }

        return depths.map { depth in
            1 - clamp((depth - minDepth) / range)
        }
    }

    private static func gridDepthScale(
        for point: SIMD3<Float>,
        camera: CameraSettings,
        falloff: GridDistanceFalloffSettings,
        minimumScale: Float
    ) -> Float {
        let depth = max(forwardDepth(for: point, camera: camera), 0)
        let fade = smoothstep(
            edge0: falloff.startDepth,
            edge1: falloff.endDepth,
            x: depth
        )
        return mix(1.0, minimumScale, t: fade)
    }

    private static func forwardDepth(
        for point: SIMD3<Float>,
        camera: CameraSettings
    ) -> Float {
        simd_dot(point - camera.position, cameraForward(camera: camera))
    }

    private static func cameraForward(camera: CameraSettings) -> SIMD3<Float> {
        let forward = MatrixMath.effectiveTarget(for: camera) - camera.position
        let lengthSquared = simd_length_squared(forward)
        guard lengthSquared > 0.0001 else {
            return SIMD3<Float>(0, 0, -1)
        }
        return forward / sqrt(lengthSquared)
    }

    private static func applyStyle(
        _ color: SIMD4<Float>,
        intensity: Float,
        opacity: Float
    ) -> SIMD4<Float> {
        SIMD4<Float>(
            color.x * intensity,
            color.y * intensity,
            color.z * intensity,
            opacity
        )
    }

    private static func mix(_ start: SIMD4<Float>, _ end: SIMD4<Float>, t: Float) -> SIMD4<Float> {
        start + ((end - start) * t)
    }

    private static func mix(_ start: Float, _ end: Float, t: Float) -> Float {
        start + ((end - start) * t)
    }

    private static func smoothstep(edge0: Float, edge1: Float, x: Float) -> Float {
        let t = clamp((x - edge0) / max(edge1 - edge0, 0.0001))
        return t * t * (3 - (2 * t))
    }

    private static func clamp(_ value: Float) -> Float {
        max(0, min(1, value))
    }

    private static func wrappedLoopTime(_ time: Double, duration: Double) -> Double {
        let wrappedTime = time.truncatingRemainder(dividingBy: duration)
        return wrappedTime < 0 ? wrappedTime + duration : wrappedTime
    }
}
