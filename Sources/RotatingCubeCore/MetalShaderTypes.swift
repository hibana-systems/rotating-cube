import simd

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
    public var direction: SIMD2<Float>
    public var sourceTexelSize: SIMD2<Float>

    public init(direction: SIMD2<Float>, sourceTexelSize: SIMD2<Float>) {
        self.direction = direction
        self.sourceTexelSize = sourceTexelSize
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
        self.time = time
    }
}
