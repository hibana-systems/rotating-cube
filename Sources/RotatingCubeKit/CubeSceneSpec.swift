import Foundation
import simd

public struct RGBAColor: Sendable, Equatable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1.0) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
}

public struct ScenePalette: Sendable, Equatable {
    public var cubeCore: RGBAColor
    public var cubeGlow: RGBAColor
    public var gridCore: RGBAColor
    public var gridGlow: RGBAColor

    public init(
        cubeCore: RGBAColor,
        cubeGlow: RGBAColor,
        gridCore: RGBAColor,
        gridGlow: RGBAColor
    ) {
        self.cubeCore = cubeCore
        self.cubeGlow = cubeGlow
        self.gridCore = gridCore
        self.gridGlow = gridGlow
    }
}

public struct CubeParameters: Sendable, Equatable {
    public var size: Double
    public var center: SIMD3<Double>
    public var lineRadius: Double
    public var glowRadiusMultiplier: Double
    public var xTiltDegrees: Double
    public var yRotationDegrees: Double

    public init(
        size: Double,
        center: SIMD3<Double>,
        lineRadius: Double,
        glowRadiusMultiplier: Double,
        xTiltDegrees: Double,
        yRotationDegrees: Double
    ) {
        self.size = size
        self.center = center
        self.lineRadius = lineRadius
        self.glowRadiusMultiplier = glowRadiusMultiplier
        self.xTiltDegrees = xTiltDegrees
        self.yRotationDegrees = yRotationDegrees
    }
}

public struct GridParameters: Sendable, Equatable {
    public var extent: Int
    public var spacing: Double
    public var y: Double
    public var lineRadius: Double
    public var glowRadiusMultiplier: Double

    public init(
        extent: Int,
        spacing: Double,
        y: Double,
        lineRadius: Double,
        glowRadiusMultiplier: Double
    ) {
        self.extent = extent
        self.spacing = spacing
        self.y = y
        self.lineRadius = lineRadius
        self.glowRadiusMultiplier = glowRadiusMultiplier
    }
}

public struct CameraParameters: Sendable, Equatable {
    public var position: SIMD3<Double>
    public var target: SIMD3<Double>
    public var fieldOfViewDegrees: Double

    public init(position: SIMD3<Double>, target: SIMD3<Double>, fieldOfViewDegrees: Double) {
        self.position = position
        self.target = target
        self.fieldOfViewDegrees = fieldOfViewDegrees
    }
}

public struct RotationParameters: Sendable, Equatable {
    public var xAxisDuration: Double
    public var yAxisDuration: Double

    public init(xAxisDuration: Double, yAxisDuration: Double) {
        self.xAxisDuration = xAxisDuration
        self.yAxisDuration = yAxisDuration
    }
}

public struct CubeSceneSpec: Sendable, Equatable {
    public var palette: ScenePalette
    public var cube: CubeParameters
    public var grid: GridParameters
    public var camera: CameraParameters
    public var rotation: RotationParameters

    public init(
        palette: ScenePalette,
        cube: CubeParameters,
        grid: GridParameters,
        camera: CameraParameters,
        rotation: RotationParameters
    ) {
        self.palette = palette
        self.cube = cube
        self.grid = grid
        self.camera = camera
        self.rotation = rotation
    }

    public static let defaultScene = CubeSceneSpec(
        palette: ScenePalette(
            cubeCore: RGBAColor(red: 0.78, green: 1.00, blue: 0.84, alpha: 0.98),
            cubeGlow: RGBAColor(red: 0.34, green: 1.00, blue: 0.55, alpha: 0.88),
            gridCore: RGBAColor(red: 0.20, green: 0.98, blue: 0.53, alpha: 0.66),
            gridGlow: RGBAColor(red: 0.16, green: 0.86, blue: 0.44, alpha: 0.34)
        ),
        cube: CubeParameters(
            size: 3.2,
            center: SIMD3<Double>(0, 2.3, 0),
            lineRadius: 0.0135,
            glowRadiusMultiplier: 1.8,
            xTiltDegrees: 30,
            yRotationDegrees: 45
        ),
        grid: GridParameters(
            extent: 14,
            spacing: 0.72,
            y: 0.0,
            lineRadius: 0.006,
            glowRadiusMultiplier: 1.45
        ),
        camera: CameraParameters(
            position: SIMD3<Double>(0, 4.8, 11.8),
            target: SIMD3<Double>(0, 2.1, 0),
            fieldOfViewDegrees: 34
        ),
        rotation: RotationParameters(
            xAxisDuration: 24.0,
            yAxisDuration: 16.0
        )
    )
}

public struct LineSegment: Sendable, Equatable {
    public var start: SIMD3<Double>
    public var end: SIMD3<Double>

    public init(start: SIMD3<Double>, end: SIMD3<Double>) {
        self.start = start
        self.end = end
    }
}
