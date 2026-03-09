import simd

enum MatrixMath {
    static func perspective(
        fieldOfViewDegrees: Float,
        aspectRatio: Float,
        nearPlane: Float,
        farPlane: Float
    ) -> simd_float4x4 {
        let fieldOfViewRadians = fieldOfViewDegrees * (.pi / 180)
        let yScale = 1 / tan(fieldOfViewRadians * 0.5)
        let xScale = yScale / aspectRatio
        let zRange = farPlane - nearPlane
        let zScale = -(farPlane + nearPlane) / zRange
        let wzScale = -2 * farPlane * nearPlane / zRange

        return simd_float4x4(
            SIMD4<Float>(xScale, 0, 0, 0),
            SIMD4<Float>(0, yScale, 0, 0),
            SIMD4<Float>(0, 0, zScale, -1),
            SIMD4<Float>(0, 0, wzScale, 0)
        )
    }

    static func lookAt(
        eye: SIMD3<Float>,
        target: SIMD3<Float>,
        up: SIMD3<Float> = SIMD3<Float>(0, 1, 0)
    ) -> simd_float4x4 {
        let forward = simd_normalize(target - eye)
        let referenceUp = simd_length_squared(up) > 0 ? simd_normalize(up) : SIMD3<Float>(0, 1, 0)
        let fallbackUp = abs(simd_dot(forward, referenceUp)) > 0.99
            ? SIMD3<Float>(0, 0, 1)
            : referenceUp
        let right = simd_normalize(simd_cross(forward, fallbackUp))
        let cameraUp = simd_cross(right, forward)
        let translation = SIMD3<Float>(
            -simd_dot(right, eye),
            -simd_dot(cameraUp, eye),
            simd_dot(forward, eye)
        )

        return simd_float4x4(
            SIMD4<Float>(right.x, right.y, right.z, 0),
            SIMD4<Float>(cameraUp.x, cameraUp.y, cameraUp.z, 0),
            SIMD4<Float>(-forward.x, -forward.y, -forward.z, 0),
            SIMD4<Float>(translation.x, translation.y, translation.z, 1)
        )
    }

    static func projectToNormalizedDeviceCoordinates(
        point: SIMD3<Float>,
        camera: CameraSettings,
        aspectRatio: Float
    ) -> SIMD2<Float>? {
        let projection = perspective(
            fieldOfViewDegrees: camera.fieldOfViewDegrees,
            aspectRatio: aspectRatio,
            nearPlane: camera.nearPlane,
            farPlane: camera.farPlane
        )
        let view = lookAt(
            eye: camera.position,
            target: camera.target,
            up: camera.upVector
        )
        let clip = simd_mul(projection * view, SIMD4<Float>(point, 1))

        guard abs(clip.w) > 0.0001 else {
            return nil
        }

        return SIMD2<Float>(clip.x / clip.w, clip.y / clip.w)
    }

    static func rotationX(_ angle: Float) -> simd_float3x3 {
        let cosine = cos(angle)
        let sine = sin(angle)

        return simd_float3x3(
            SIMD3<Float>(1, 0, 0),
            SIMD3<Float>(0, cosine, sine),
            SIMD3<Float>(0, -sine, cosine)
        )
    }

    static func rotationY(_ angle: Float) -> simd_float3x3 {
        let cosine = cos(angle)
        let sine = sin(angle)

        return simd_float3x3(
            SIMD3<Float>(cosine, 0, -sine),
            SIMD3<Float>(0, 1, 0),
            SIMD3<Float>(sine, 0, cosine)
        )
    }
}
