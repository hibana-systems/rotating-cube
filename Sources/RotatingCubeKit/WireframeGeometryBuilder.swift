import Foundation
import simd

public enum WireframeGeometryBuilder {
    public static let cubeEdgeIndices: [(Int, Int)] = [
        (0, 1), (1, 2), (2, 3), (3, 0),
        (4, 5), (5, 6), (6, 7), (7, 4),
        (0, 4), (1, 5), (2, 6), (3, 7),
    ]

    public static func cubeVertices(
        size: Double,
        center: SIMD3<Double>
    ) -> [SIMD3<Double>] {
        let half = size / 2
        return [
            SIMD3<Double>(center.x - half, center.y - half, center.z - half),
            SIMD3<Double>(center.x + half, center.y - half, center.z - half),
            SIMD3<Double>(center.x + half, center.y + half, center.z - half),
            SIMD3<Double>(center.x - half, center.y + half, center.z - half),
            SIMD3<Double>(center.x - half, center.y - half, center.z + half),
            SIMD3<Double>(center.x + half, center.y - half, center.z + half),
            SIMD3<Double>(center.x + half, center.y + half, center.z + half),
            SIMD3<Double>(center.x - half, center.y + half, center.z + half),
        ]
    }

    public static func cubeSegments(
        size: Double,
        center: SIMD3<Double>
    ) -> [LineSegment] {
        let vertices = cubeVertices(size: size, center: center)
        return cubeEdgeIndices.map { startIndex, endIndex in
            LineSegment(start: vertices[startIndex], end: vertices[endIndex])
        }
    }

    public static func gridSegments(
        extent: Int,
        spacing: Double,
        y: Double
    ) -> [LineSegment] {
        let limit = Double(extent) * spacing
        let offsets = (-extent...extent).map { Double($0) * spacing }
        var segments: [LineSegment] = []
        segments.reserveCapacity(offsets.count * 2)

        for offset in offsets {
            segments.append(
                LineSegment(
                    start: SIMD3<Double>(-limit, y, offset),
                    end: SIMD3<Double>(limit, y, offset)
                )
            )
            segments.append(
                LineSegment(
                    start: SIMD3<Double>(offset, y, -limit),
                    end: SIMD3<Double>(offset, y, limit)
                )
            )
        }

        return segments
    }
}
