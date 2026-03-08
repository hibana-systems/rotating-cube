import AppKit
import RotatingCubeKit
import SceneKit
import simd

enum SceneKitSceneBuilder {
    private enum SegmentGeometryStyle {
        case capsule
        case cylinder(overlap: Double, radialSegmentCount: Int)
    }

    struct BuiltScene {
        let scene: SCNScene
        let pointOfView: SCNNode
    }

    static func build(spec: CubeSceneSpec) -> BuiltScene {
        let scene = SCNScene()
        scene.background.contents = NSColor.clear

        let cameraNode = makeCameraNode(spec: spec)
        scene.rootNode.addChildNode(cameraNode)

        scene.rootNode.addChildNode(makeGridNode(spec: spec))
        scene.rootNode.addChildNode(makeCubeNode(spec: spec))

        return BuiltScene(scene: scene, pointOfView: cameraNode)
    }

    private static func makeCameraNode(spec: CubeSceneSpec) -> SCNNode {
        let camera = SCNCamera()
        camera.fieldOfView = spec.camera.fieldOfViewDegrees
        camera.zNear = 0.1
        camera.zFar = 120
        camera.wantsHDR = true
        camera.bloomIntensity = 1.15
        camera.bloomThreshold = 0.28
        camera.bloomBlurRadius = 9
        camera.vignettingIntensity = 0.22
        camera.vignettingPower = 0.35

        let node = SCNNode()
        node.camera = camera
        node.simdPosition = spec.camera.position.float3
        node.look(
            at: spec.camera.target.vector3,
            up: SCNVector3(0, 1, 0),
            localFront: SCNVector3(0, 0, -1)
        )
        return node
    }

    private static func makeGridNode(spec: CubeSceneSpec) -> SCNNode {
        let node = SCNNode()
        let segments = WireframeGeometryBuilder.gridSegments(
            extent: spec.grid.extent,
            spacing: spec.grid.spacing,
            y: spec.grid.y
        )

        for segment in segments {
            node.addChildNode(
                makeGlowingSegmentNode(
                    segment: segment,
                    radius: spec.grid.lineRadius,
                    glowRadiusMultiplier: spec.grid.glowRadiusMultiplier,
                    coreColor: spec.palette.gridCore.nsColor,
                    haloColor: spec.palette.gridGlow.nsColor,
                    coreOpacity: 0.54,
                    haloOpacity: 0.08
                )
            )
        }

        return node
    }

    private static func makeCubeNode(spec: CubeSceneSpec) -> SCNNode {
        let centerNode = SCNNode()
        centerNode.simdPosition = spec.cube.center.float3

        let yawNode = SCNNode()
        yawNode.simdEulerAngles = SIMD3<Float>(
            0,
            Float(spec.cube.yRotationDegrees * .pi / 180),
            0
        )

        let pitchNode = SCNNode()
        pitchNode.simdEulerAngles = SIMD3<Float>(
            Float(spec.cube.xTiltDegrees * .pi / 180),
            0,
            0
        )

        let vertices = WireframeGeometryBuilder.cubeVertices(
            size: spec.cube.size,
            center: .zero
        )
        let spectralSubdivisionCount = 36

        for (startIndex, endIndex) in WireframeGeometryBuilder.cubeEdgeIndices {
            let start = vertices[startIndex]
            let end = vertices[endIndex]
            let edge = LineSegment(start: start, end: end)

            for segment in subdividedSegments(edge, count: spectralSubdivisionCount) {
                let midpoint = (segment.start + segment.end) / 2
                let color = boostSaturation(
                    spectralColor(for: midpoint, cubeSize: spec.cube.size),
                    multiplier: 1.15
                )

                pitchNode.addChildNode(
                    makeGlowingSegmentNode(
                        segment: segment,
                        radius: spec.cube.lineRadius,
                        glowRadiusMultiplier: spec.cube.glowRadiusMultiplier,
                        coreColor: color,
                        haloColor: color,
                        coreOpacity: 0.96,
                        haloOpacity: 0.22,
                        coreBlendMode: .alpha,
                        haloBlendMode: .screen,
                        coreWritesToDepthBuffer: true,
                        haloWritesToDepthBuffer: false,
                        readsFromDepthBuffer: true,
                        style: .cylinder(
                            overlap: spec.cube.lineRadius * 1.6,
                            radialSegmentCount: 18
                        )
                    )
                )
            }
        }

        yawNode.addChildNode(pitchNode)
        centerNode.addChildNode(yawNode)

        let ySpin = SCNAction.rotateBy(
            x: 0,
            y: .pi * 2,
            z: 0,
            duration: spec.rotation.yAxisDuration
        )
        yawNode.runAction(.repeatForever(ySpin))

        let xSpin = SCNAction.rotateBy(
            x: -.pi * 2,
            y: 0,
            z: 0,
            duration: spec.rotation.xAxisDuration
        )
        pitchNode.runAction(.repeatForever(xSpin))

        return centerNode
    }

    private static func makeGlowingSegmentNode(
        segment: LineSegment,
        radius: Double,
        glowRadiusMultiplier: Double,
        coreColor: NSColor,
        haloColor: NSColor,
        coreOpacity: CGFloat,
        haloOpacity: CGFloat,
        coreBlendMode: SCNBlendMode = .add,
        haloBlendMode: SCNBlendMode = .add,
        coreWritesToDepthBuffer: Bool = false,
        haloWritesToDepthBuffer: Bool = false,
        readsFromDepthBuffer: Bool = false,
        style: SegmentGeometryStyle = .capsule
    ) -> SCNNode {
        let node = SCNNode()
        node.addChildNode(
            makeSegmentNode(
                segment: segment,
                radius: radius * glowRadiusMultiplier,
                diffuseColor: haloColor.withAlphaComponent(haloOpacity * 0.18),
                emissionColor: haloColor.withAlphaComponent(haloOpacity),
                blendMode: haloBlendMode,
                writesToDepthBuffer: haloWritesToDepthBuffer,
                readsFromDepthBuffer: readsFromDepthBuffer,
                style: style
            )
        )
        node.addChildNode(
            makeSegmentNode(
                segment: segment,
                radius: radius,
                diffuseColor: coreColor.withAlphaComponent(coreOpacity * 0.28),
                emissionColor: coreColor.withAlphaComponent(coreOpacity),
                blendMode: coreBlendMode,
                writesToDepthBuffer: coreWritesToDepthBuffer,
                readsFromDepthBuffer: readsFromDepthBuffer,
                style: style
            )
        )
        return node
    }

    private static func makeSegmentNode(
        segment: LineSegment,
        radius: Double,
        diffuseColor: NSColor,
        emissionColor: NSColor,
        blendMode: SCNBlendMode,
        writesToDepthBuffer: Bool,
        readsFromDepthBuffer: Bool,
        style: SegmentGeometryStyle
    ) -> SCNNode {
        let vector = segment.end - segment.start
        let length = simd_length(vector)

        let geometry: SCNGeometry

        switch style {
        case .capsule:
            geometry = SCNCapsule(capRadius: radius, height: length)
        case let .cylinder(overlap, radialSegmentCount):
            let cylinder = SCNCylinder(radius: radius, height: length + overlap)
            cylinder.radialSegmentCount = radialSegmentCount
            geometry = cylinder
        }

        let material = SCNMaterial()
        material.lightingModel = .constant
        material.diffuse.contents = diffuseColor
        material.emission.contents = emissionColor
        material.roughness.contents = 1.0
        material.metalness.contents = 0.0
        material.blendMode = blendMode
        material.writesToDepthBuffer = writesToDepthBuffer
        material.readsFromDepthBuffer = readsFromDepthBuffer
        material.isDoubleSided = true
        geometry.firstMaterial = material

        let node = SCNNode(geometry: geometry)
        node.simdPosition = ((segment.start + segment.end) / 2).float3
        node.simdOrientation = rotationQuaternion(
            from: SIMD3<Double>(0, 1, 0),
            to: vector
        )
        node.castsShadow = false
        return node
    }

    private static func rotationQuaternion(
        from start: SIMD3<Double>,
        to end: SIMD3<Double>
    ) -> simd_quatf {
        let normalizedStart = simd_normalize(start)
        let normalizedEnd = simd_normalize(end)
        let dotProduct = simd_dot(normalizedStart, normalizedEnd)

        if dotProduct > 0.9999 {
            return simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))
        }

        if dotProduct < -0.9999 {
            let fallbackAxis = abs(normalizedStart.x) < 0.9
                ? simd_cross(normalizedStart, SIMD3<Double>(1, 0, 0))
                : simd_cross(normalizedStart, SIMD3<Double>(0, 0, 1))
            let axis = SIMD3<Float>(
                Float(fallbackAxis.x),
                Float(fallbackAxis.y),
                Float(fallbackAxis.z)
            )
            return simd_quatf(angle: .pi, axis: simd_normalize(axis))
        }

        let axis = simd_normalize(simd_cross(normalizedStart, normalizedEnd))
        let angle = acos(max(-1, min(1, dotProduct)))
        return simd_quatf(
            angle: Float(angle),
            axis: SIMD3<Float>(Float(axis.x), Float(axis.y), Float(axis.z))
        )
    }

    private static func subdividedSegments(_ segment: LineSegment, count: Int) -> [LineSegment] {
        guard count > 1 else {
            return [segment]
        }

        return (0..<count).map { index in
            let startT = Double(index) / Double(count)
            let endT = Double(index + 1) / Double(count)

            return LineSegment(
                start: mix(segment.start, segment.end, t: startT),
                end: mix(segment.start, segment.end, t: endT)
            )
        }
    }

    private static func spectralColor(
        for point: SIMD3<Double>,
        cubeSize: Double
    ) -> NSColor {
        let half = cubeSize / 2
        let u = clamp((point.x + half) / cubeSize)
        let v = clamp((point.y + half) / cubeSize)
        let w = clamp((point.z + half) / cubeSize)

        let c00 = mix(spectralCornerColors[0], spectralCornerColors[1], t: u)
        let c10 = mix(spectralCornerColors[3], spectralCornerColors[2], t: u)
        let c01 = mix(spectralCornerColors[4], spectralCornerColors[5], t: u)
        let c11 = mix(spectralCornerColors[7], spectralCornerColors[6], t: u)
        let c0 = mix(c00, c10, t: v)
        let c1 = mix(c01, c11, t: v)
        let color = mix(c0, c1, t: w)

        return NSColor(
            red: color.x,
            green: color.y,
            blue: color.z,
            alpha: color.w
        )
    }

    private static func mix(
        _ start: SIMD3<Double>,
        _ end: SIMD3<Double>,
        t: Double
    ) -> SIMD3<Double> {
        start + ((end - start) * t)
    }

    private static func mix(
        _ start: SIMD4<Double>,
        _ end: SIMD4<Double>,
        t: Double
    ) -> SIMD4<Double> {
        let amount = t
        return start + ((end - start) * amount)
    }

    private static func clamp(_ value: Double) -> Double {
        max(0, min(1, value))
    }

    private static func boostSaturation(
        _ color: NSColor,
        multiplier: CGFloat
    ) -> NSColor {
        let rgbColor = color.usingColorSpace(.deviceRGB) ?? color
        return NSColor(
            hue: rgbColor.hueComponent,
            saturation: min(rgbColor.saturationComponent * multiplier, 1.0),
            brightness: rgbColor.brightnessComponent,
            alpha: rgbColor.alphaComponent
        )
    }
}

private extension RGBAColor {
    var nsColor: NSColor {
        NSColor(
            red: red,
            green: green,
            blue: blue,
            alpha: alpha
        )
    }
}

private extension SIMD3<Double> {
    var float3: SIMD3<Float> {
        SIMD3<Float>(Float(x), Float(y), Float(z))
    }

    var vector3: SCNVector3 {
        SCNVector3(x, y, z)
    }
}

private let spectralCornerColors: [SIMD4<Double>] = [
    SIMD4<Double>(0.26, 0.60, 1.00, 1.0),
    SIMD4<Double>(0.70, 0.48, 1.00, 1.0),
    SIMD4<Double>(1.00, 0.82, 0.32, 1.0),
    SIMD4<Double>(0.44, 0.94, 1.00, 1.0),
    SIMD4<Double>(0.36, 1.00, 0.94, 1.0),
    SIMD4<Double>(1.00, 0.44, 0.86, 1.0),
    SIMD4<Double>(1.00, 0.60, 0.50, 1.0),
    SIMD4<Double>(0.58, 1.00, 0.98, 1.0),
]
