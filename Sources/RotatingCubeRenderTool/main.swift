import Foundation
import RotatingCubeCore

struct RenderToolOptions {
    var outputURL: URL
    var width: Int
    var height: Int
    var durationSeconds: Double

    init(arguments: [String], defaults: SceneSpec) throws {
        var outputURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("RotatingCube-4K-Loop.mp4")
        var width = defaults.output.width
        var height = defaults.output.height
        var durationSeconds = defaults.loop.durationSeconds

        var iterator = arguments.dropFirst().makeIterator()

        while let argument = iterator.next() {
            switch argument {
            case "--output":
                guard let value = iterator.next() else { continue }
                outputURL = URL(fileURLWithPath: value)
            case "--width":
                guard let value = iterator.next(), let parsed = Int(value) else { continue }
                width = parsed
            case "--height":
                guard let value = iterator.next(), let parsed = Int(value) else { continue }
                height = parsed
            case "--seconds":
                guard let value = iterator.next(), let parsed = Double(value) else { continue }
                durationSeconds = parsed
            default:
                continue
            }
        }

        self.outputURL = outputURL
        self.width = width
        self.height = height
        self.durationSeconds = durationSeconds
    }
}

let sceneSpec = SceneSpec.defaultWallpaper
let options = try RenderToolOptions(arguments: CommandLine.arguments, defaults: sceneSpec)
let exporter = try RotatingCubeVideoExporter(
    sceneSpec: sceneSpec,
    shaderBundle: .main
)

let outputSettings = OutputSettings(
    width: options.width,
    height: options.height,
    codec: sceneSpec.output.codec,
    averageBitRate: sceneSpec.output.averageBitRate
)

print(
    "Rendering \(Int(options.durationSeconds))s to \(options.width)x\(options.height) -> \(options.outputURL.path)"
)
try exporter.export(
    to: options.outputURL,
    outputSettings: outputSettings,
    durationSeconds: options.durationSeconds
)
print("Finished \(options.outputURL.path)")
