import Foundation
import simd

public struct RGBAColor: Sendable, Equatable {
    public var red: Float
    public var green: Float
    public var blue: Float
    public var alpha: Float

    public init(red: Float, green: Float, blue: Float, alpha: Float = 1.0) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    public var simd: SIMD4<Float> {
        SIMD4<Float>(red, green, blue, alpha)
    }
}

public struct LineStyle: Sendable, Equatable {
    public var coreWidthPixels: Float
    public var glowWidthPixels: Float
    public var coreOpacity: Float
    public var glowOpacity: Float

    public init(
        coreWidthPixels: Float,
        glowWidthPixels: Float,
        coreOpacity: Float,
        glowOpacity: Float
    ) {
        self.coreWidthPixels = coreWidthPixels
        self.glowWidthPixels = glowWidthPixels
        self.coreOpacity = coreOpacity
        self.glowOpacity = glowOpacity
    }
}

public struct ScenePalette: Sendable, Equatable {
    public var cubeCornerColors: [RGBAColor]
    public var gridCore: RGBAColor
    public var gridGlow: RGBAColor
    public var background: RGBAColor

    public init(
        cubeCornerColors: [RGBAColor],
        gridCore: RGBAColor,
        gridGlow: RGBAColor,
        background: RGBAColor
    ) {
        precondition(cubeCornerColors.count == 8, "Cube palette requires 8 corner colors.")
        self.cubeCornerColors = cubeCornerColors
        self.gridCore = gridCore
        self.gridGlow = gridGlow
        self.background = background
    }
}

public struct CubeSettings: Sendable, Equatable {
    public var size: Float
    public var center: SIMD3<Float>
    public var lineStyle: LineStyle
    public var xTiltDegrees: Float
    public var initialYawDegrees: Float
    public var xRevolutionsPerLoop: Int
    public var yRevolutionsPerLoop: Int

    public init(
        size: Float,
        center: SIMD3<Float>,
        lineStyle: LineStyle,
        xTiltDegrees: Float,
        initialYawDegrees: Float,
        xRevolutionsPerLoop: Int,
        yRevolutionsPerLoop: Int
    ) {
        self.size = size
        self.center = center
        self.lineStyle = lineStyle
        self.xTiltDegrees = xTiltDegrees
        self.initialYawDegrees = initialYawDegrees
        self.xRevolutionsPerLoop = xRevolutionsPerLoop
        self.yRevolutionsPerLoop = yRevolutionsPerLoop
    }
}

public struct GridSettings: Sendable, Equatable {
    public var extent: Int
    public var spacing: Float
    public var y: Float
    public var lineStyle: LineStyle

    public init(
        extent: Int,
        spacing: Float,
        y: Float,
        lineStyle: LineStyle
    ) {
        self.extent = extent
        self.spacing = spacing
        self.y = y
        self.lineStyle = lineStyle
    }
}

public struct CameraSettings: Sendable, Equatable {
    public var position: SIMD3<Float>
    public var target: SIMD3<Float>
    public var fieldOfViewDegrees: Float
    public var nearPlane: Float
    public var farPlane: Float

    public init(
        position: SIMD3<Float>,
        target: SIMD3<Float>,
        fieldOfViewDegrees: Float,
        nearPlane: Float,
        farPlane: Float
    ) {
        self.position = position
        self.target = target
        self.fieldOfViewDegrees = fieldOfViewDegrees
        self.nearPlane = nearPlane
        self.farPlane = farPlane
    }
}

public struct LoopSettings: Sendable, Equatable {
    public var durationSeconds: Double
    public var simulationFPS: Int
    public var outputFPS: Int

    public init(durationSeconds: Double, simulationFPS: Int, outputFPS: Int) {
        precondition(durationSeconds > 0, "Loop duration must be positive.")
        precondition(simulationFPS > 0, "Simulation FPS must be positive.")
        precondition(outputFPS > 0, "Output FPS must be positive.")
        precondition(
            outputFPS % simulationFPS == 0,
            "Output FPS must be an even multiple of simulation FPS."
        )
        self.durationSeconds = durationSeconds
        self.simulationFPS = simulationFPS
        self.outputFPS = outputFPS
    }

    public var simulationFrameCount: Int {
        Int(durationSeconds * Double(simulationFPS))
    }

    public var presentationFrameCount: Int {
        Int(durationSeconds * Double(outputFPS))
    }
}

public struct AntiAliasingSettings: Sendable, Equatable {
    public var isEnabled: Bool
    public var edgeFeatherWidth: Float
    public var edgeSoftness: Float

    public init(isEnabled: Bool, edgeFeatherWidth: Float, edgeSoftness: Float) {
        self.isEnabled = isEnabled
        self.edgeFeatherWidth = edgeFeatherWidth
        self.edgeSoftness = edgeSoftness
    }
}

public struct CRTSettings: Sendable, Equatable {
    public var bloomThreshold: Float
    public var bloomIntensity: Float
    public var bloomRadius: Float
    public var scanlineIntensity: Float
    public var scanlineDensity: Float
    public var phosphorMaskIntensity: Float
    public var vignetteIntensity: Float
    public var barrelDistortion: Float
    public var cornerPinch: Float

    public init(
        bloomThreshold: Float,
        bloomIntensity: Float,
        bloomRadius: Float,
        scanlineIntensity: Float,
        scanlineDensity: Float,
        phosphorMaskIntensity: Float,
        vignetteIntensity: Float,
        barrelDistortion: Float,
        cornerPinch: Float
    ) {
        self.bloomThreshold = bloomThreshold
        self.bloomIntensity = bloomIntensity
        self.bloomRadius = bloomRadius
        self.scanlineIntensity = scanlineIntensity
        self.scanlineDensity = scanlineDensity
        self.phosphorMaskIntensity = phosphorMaskIntensity
        self.vignetteIntensity = vignetteIntensity
        self.barrelDistortion = barrelDistortion
        self.cornerPinch = cornerPinch
    }
}

public enum VideoCodec: String, Sendable, Equatable {
    case h264
    case hevc
}

public struct OutputSettings: Sendable, Equatable {
    public var width: Int
    public var height: Int
    public var codec: VideoCodec
    public var averageBitRate: Int

    public init(width: Int, height: Int, codec: VideoCodec, averageBitRate: Int) {
        self.width = width
        self.height = height
        self.codec = codec
        self.averageBitRate = averageBitRate
    }
}

public struct SceneSpec: Sendable, Equatable {
    public var palette: ScenePalette
    public var cube: CubeSettings
    public var grid: GridSettings
    public var camera: CameraSettings
    public var loop: LoopSettings
    public var antiAliasing: AntiAliasingSettings
    public var crt: CRTSettings
    public var output: OutputSettings

    public init(
        palette: ScenePalette,
        cube: CubeSettings,
        grid: GridSettings,
        camera: CameraSettings,
        loop: LoopSettings,
        antiAliasing: AntiAliasingSettings,
        crt: CRTSettings,
        output: OutputSettings
    ) {
        self.palette = palette
        self.cube = cube
        self.grid = grid
        self.camera = camera
        self.loop = loop
        self.antiAliasing = antiAliasing
        self.crt = crt
        self.output = output
    }

    public static let defaultWallpaper = SceneSpec(
        palette: ScenePalette(
            cubeCornerColors: [
                RGBAColor(red: 0.28, green: 0.62, blue: 1.00),
                RGBAColor(red: 0.76, green: 0.42, blue: 1.00),
                RGBAColor(red: 1.00, green: 0.84, blue: 0.28),
                RGBAColor(red: 0.34, green: 1.00, blue: 0.98),
                RGBAColor(red: 0.34, green: 1.00, blue: 0.88),
                RGBAColor(red: 1.00, green: 0.42, blue: 0.88),
                RGBAColor(red: 1.00, green: 0.62, blue: 0.44),
                RGBAColor(red: 0.56, green: 1.00, blue: 1.00),
            ],
            gridCore: RGBAColor(red: 0.12, green: 0.96, blue: 0.22, alpha: 1.0),
            gridGlow: RGBAColor(red: 0.08, green: 0.72, blue: 0.16, alpha: 1.0),
            background: RGBAColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        ),
        cube: CubeSettings(
            size: 3.2,
            center: SIMD3<Float>(0, 2.65, 0),
            lineStyle: LineStyle(
                coreWidthPixels: 3.0,
                glowWidthPixels: 5.4,
                coreOpacity: 0.98,
                glowOpacity: 0.18
            ),
            xTiltDegrees: 30,
            initialYawDegrees: 45,
            xRevolutionsPerLoop: 1,
            yRevolutionsPerLoop: 2
        ),
        grid: GridSettings(
            extent: 14,
            spacing: 0.72,
            y: 0.0,
            lineStyle: LineStyle(
                coreWidthPixels: 1.4,
                glowWidthPixels: 2.3,
                coreOpacity: 0.72,
                glowOpacity: 0.08
            )
        ),
        camera: CameraSettings(
            position: SIMD3<Float>(0, 4.8, 11.8),
            target: SIMD3<Float>(0, 2.1, 0),
            fieldOfViewDegrees: 34,
            nearPlane: 0.1,
            farPlane: 120
        ),
        loop: LoopSettings(
            durationSeconds: 30,
            simulationFPS: 20,
            outputFPS: 60
        ),
        antiAliasing: AntiAliasingSettings(
            isEnabled: true,
            edgeFeatherWidth: 1.25,
            edgeSoftness: 1.0
        ),
        crt: CRTSettings(
            bloomThreshold: 0.42,
            bloomIntensity: 0.0,
            bloomRadius: 1.8,
            scanlineIntensity: 0.0,
            scanlineDensity: 1.0,
            phosphorMaskIntensity: 0.0,
            vignetteIntensity: 0.0,
            barrelDistortion: 0.0,
            cornerPinch: 0.0
        ),
        output: OutputSettings(
            width: 3840,
            height: 2160,
            codec: .h264,
            averageBitRate: 30_000_000
        )
    )
}
