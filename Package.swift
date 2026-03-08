// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "RotatingCube",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "RotatingCube", targets: ["RotatingCube"]),
    ],
    targets: [
        .executableTarget(
            name: "RotatingCube",
            dependencies: ["RotatingCubeKit"]
        ),
        .target(name: "RotatingCubeKit"),
        .testTarget(
            name: "RotatingCubeTests",
            dependencies: ["RotatingCubeKit"]
        ),
    ]
)
