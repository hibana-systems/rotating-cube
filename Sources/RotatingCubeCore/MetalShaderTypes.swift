import simd

enum BloomSampling {
    static let blurTapCount = 4

    static func blurOffsets(
        direction: SIMD2<Float>,
        texelSize: SIMD2<Float>,
        radius: Float
    ) -> [SIMD2<Float>] {
        let directionLengthSquared = simd_length_squared(direction)
        let normalizedDirection = directionLengthSquared > 0.0001
            ? direction / sqrt(directionLengthSquared)
            : SIMD2<Float>(repeating: 0)
        let clampedRadius = max(radius, 0)
        let basis = normalizedDirection * texelSize * clampedRadius

        return (1...blurTapCount).map { index in
            basis * Float(index)
        }
    }
}

public struct GPUSceneLineInstance {
    public var startPosition: SIMD3<Float>
    public var endPosition: SIMD3<Float>
    public var coreStartColor: SIMD4<Float>
    public var coreEndColor: SIMD4<Float>
    public var glowStartColor: SIMD4<Float>
    public var glowEndColor: SIMD4<Float>
    public var coreWidth: Float
    public var glowWidth: Float

    public init(
        startPosition: SIMD3<Float>,
        endPosition: SIMD3<Float>,
        coreStartColor: SIMD4<Float>,
        coreEndColor: SIMD4<Float>,
        glowStartColor: SIMD4<Float>,
        glowEndColor: SIMD4<Float>,
        coreWidth: Float,
        glowWidth: Float
    ) {
        self.startPosition = startPosition
        self.endPosition = endPosition
        self.coreStartColor = coreStartColor
        self.coreEndColor = coreEndColor
        self.glowStartColor = glowStartColor
        self.glowEndColor = glowEndColor
        self.coreWidth = coreWidth
        self.glowWidth = glowWidth
    }
}

public struct GPULineVertexUniforms {
    public var viewProjectionMatrix: simd_float4x4
    public var viewportSize: SIMD2<Float>

    public init(viewProjectionMatrix: simd_float4x4, viewportSize: SIMD2<Float>) {
        self.viewProjectionMatrix = viewProjectionMatrix
        self.viewportSize = viewportSize
    }
}

public struct GPULinePassUniforms {
    public var passKind: UInt32
    public var aaEnabled: UInt32
    public var edgeFeatherWidth: Float
    public var edgeSoftness: Float

    public init(
        passKind: UInt32,
        aaEnabled: UInt32,
        edgeFeatherWidth: Float,
        edgeSoftness: Float
    ) {
        self.passKind = passKind
        self.aaEnabled = aaEnabled
        self.edgeFeatherWidth = edgeFeatherWidth
        self.edgeSoftness = edgeSoftness
    }
}

public struct GPUBrightPassUniforms {
    public var bloomThreshold: Float
    public var padding: SIMD3<Float>

    public init(bloomThreshold: Float) {
        self.bloomThreshold = bloomThreshold
        self.padding = SIMD3<Float>(repeating: 0)
    }
}

public struct GPUBlurUniforms {
    public var sampleOffset1: SIMD2<Float>
    public var sampleOffset2: SIMD2<Float>
    public var sampleOffset3: SIMD2<Float>
    public var sampleOffset4: SIMD2<Float>

    public init(sampleOffsets: [SIMD2<Float>]) {
        precondition(sampleOffsets.count == BloomSampling.blurTapCount, "Expected four blur offsets.")
        self.sampleOffset1 = sampleOffsets[0]
        self.sampleOffset2 = sampleOffsets[1]
        self.sampleOffset3 = sampleOffsets[2]
        self.sampleOffset4 = sampleOffsets[3]
    }
}

public struct GPUCompositeUniforms {
    public var resolution: SIMD2<Float>
    public var bloomIntensity: Float
    public var scanlineIntensity: Float
    public var scanlineDensity: Float
    public var phosphorMaskIntensity: Float
    public var vignetteIntensity: Float
    public var barrelDistortion: Float
    public var cornerPinch: Float
    public var edgeFillMode: Float
    public var overscanScaleX: Float
    public var overscanScaleY: Float
    public var time: Float

    public init(
        resolution: SIMD2<Float>,
        bloomIntensity: Float,
        scanlineIntensity: Float,
        scanlineDensity: Float,
        phosphorMaskIntensity: Float,
        vignetteIntensity: Float,
        barrelDistortion: Float,
        cornerPinch: Float,
        edgeFillMode: Float,
        overscanScaleX: Float,
        overscanScaleY: Float,
        time: Float
    ) {
        self.resolution = resolution
        self.bloomIntensity = bloomIntensity
        self.scanlineIntensity = scanlineIntensity
        self.scanlineDensity = scanlineDensity
        self.phosphorMaskIntensity = phosphorMaskIntensity
        self.vignetteIntensity = vignetteIntensity
        self.barrelDistortion = barrelDistortion
        self.cornerPinch = cornerPinch
        self.edgeFillMode = edgeFillMode
        self.overscanScaleX = overscanScaleX
        self.overscanScaleY = overscanScaleY
        self.time = time
    }
}
