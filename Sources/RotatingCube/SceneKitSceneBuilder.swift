import AppKit
import RotatingCubeKit
import SceneKit
import simd

enum SceneKitSceneBuilder {
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

        let segments = WireframeGeometryBuilder.cubeSegments(
            size: spec.cube.size,
            center: .zero
        )

        for segment in segments {
            pitchNode.addChildNode(
                makeGlowingSegmentNode(
                    segment: segment,
                    radius: spec.cube.lineRadius,
                    glowRadiusMultiplier: spec.cube.glowRadiusMultiplier,
                    coreColor: spec.palette.cubeCore.nsColor,
                    haloColor: spec.palette.cubeGlow.nsColor,
                    coreOpacity: 0.80,
                    haloOpacity: 0.18
                )
            )
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
        haloOpacity: CGFloat
    ) -> SCNNode {
        let node = SCNNode()
        node.addChildNode(
            makeCapsuleSegmentNode(
                segment: segment,
                radius: radius * glowRadiusMultiplier,
                diffuseColor: haloColor.withAlphaComponent(haloOpacity * 0.18),
                emissionColor: haloColor.withAlphaComponent(haloOpacity)
            )
        )
        node.addChildNode(
            makeCapsuleSegmentNode(
                segment: segment,
                radius: radius,
                diffuseColor: coreColor.withAlphaComponent(coreOpacity * 0.28),
                emissionColor: coreColor.withAlphaComponent(coreOpacity)
            )
        )
        return node
    }

    private static func makeCapsuleSegmentNode(
        segment: LineSegment,
        radius: Double,
        diffuseColor: NSColor,
        emissionColor: NSColor
    ) -> SCNNode {
        let vector = segment.end - segment.start
        let length = simd_length(vector)

        let geometry = SCNCapsule(capRadius: radius, height: length)
        let material = SCNMaterial()
        material.lightingModel = .constant
        material.diffuse.contents = diffuseColor
        material.emission.contents = emissionColor
        material.roughness.contents = 1.0
        material.metalness.contents = 0.0
        material.blendMode = .add
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
