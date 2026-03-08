@preconcurrency import AVFoundation
import CoreMedia
import CoreVideo
import Foundation
import Metal
import VideoToolbox

public enum RotatingCubeVideoExporterError: Error {
    case metalUnavailable
    case pixelBufferPoolUnavailable
    case writerInputUnavailable
    case bufferCreationFailed
    case textureCreationFailed
    case writerFailed(String)
}

public final class RotatingCubeVideoExporter {
    public let sceneSpec: SceneSpec

    private let device: MTLDevice
    private let renderer: RotatingCubeMetalRenderer
    private let commandQueue: MTLCommandQueue
    private let textureCache: CVMetalTextureCache

    public init(
        sceneSpec: SceneSpec = .defaultWallpaper,
        shaderBundle: Bundle
    ) throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw RotatingCubeVideoExporterError.metalUnavailable
        }

        self.sceneSpec = sceneSpec
        self.device = device
        self.renderer = try RotatingCubeMetalRenderer(
            device: device,
            sceneSpec: sceneSpec,
            shaderBundle: shaderBundle
        )
        guard let commandQueue = device.makeCommandQueue() else {
            throw RotatingCubeMetalRendererError.commandQueueUnavailable
        }
        self.commandQueue = commandQueue

        var textureCache: CVMetalTextureCache?
        CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &textureCache)
        guard let textureCache else {
            throw RotatingCubeVideoExporterError.textureCreationFailed
        }
        self.textureCache = textureCache
    }

    public func export(
        to outputURL: URL,
        outputSettings: OutputSettings? = nil,
        durationSeconds: Double? = nil
    ) throws {
        let output = outputSettings ?? sceneSpec.output
        let duration = durationSeconds ?? sceneSpec.loop.durationSeconds
        let outputFPS = sceneSpec.loop.outputFPS
        let frameCount = Int(duration * Double(outputFPS))
        let effectiveLoop = LoopSettings(
            durationSeconds: duration,
            simulationFPS: sceneSpec.loop.simulationFPS,
            outputFPS: outputFPS
        )
        let effectiveTimeline = RendererTimeline(loop: effectiveLoop)

        try? FileManager.default.removeItem(at: outputURL)

        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        let writerBox = AssetWriterBox(writer)
        let videoInput = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: makeVideoSettings(output: output)
        )
        videoInput.expectsMediaDataInRealTime = false

        let pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: output.width,
            kCVPixelBufferHeightKey as String: output.height,
            kCVPixelBufferMetalCompatibilityKey as String: true,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:],
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: pixelBufferAttributes
        )

        guard writer.canAdd(videoInput) else {
            throw RotatingCubeVideoExporterError.writerInputUnavailable
        }

        writer.add(videoInput)

        guard writer.startWriting() else {
            throw RotatingCubeVideoExporterError.writerFailed(
                writer.error?.localizedDescription ?? "Unknown startWriting failure."
            )
        }

        writer.startSession(atSourceTime: .zero)

        guard let pixelBufferPool = adaptor.pixelBufferPool else {
            throw RotatingCubeVideoExporterError.pixelBufferPoolUnavailable
        }

        for frameIndex in 0..<frameCount {
            while !videoInput.isReadyForMoreMediaData {
                Thread.sleep(forTimeInterval: 0.005)
            }

            var pixelBuffer: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, pixelBufferPool, &pixelBuffer)
            guard let pixelBuffer else {
                throw RotatingCubeVideoExporterError.bufferCreationFailed
            }

            guard
                let commandBuffer = commandQueue.makeCommandBuffer(),
                let metalTexture = makeMetalTexture(
                    pixelBuffer: pixelBuffer,
                    width: output.width,
                    height: output.height
                )
            else {
                throw RotatingCubeVideoExporterError.textureCreationFailed
            }

            renderer.renderPresentationFrame(
                index: frameIndex,
                destinationTexture: metalTexture,
                destinationSize: CGSize(width: output.width, height: output.height),
                commandBuffer: commandBuffer,
                timeline: effectiveTimeline
            )
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()

            let presentationTime = CMTime(
                value: CMTimeValue(frameIndex),
                timescale: CMTimeScale(outputFPS)
            )
            guard adaptor.append(pixelBuffer, withPresentationTime: presentationTime) else {
                throw RotatingCubeVideoExporterError.writerFailed(
                    writer.error?.localizedDescription ?? "Unknown append failure."
                )
            }
        }

        videoInput.markAsFinished()

        let semaphore = DispatchSemaphore(value: 0)
        let finishState = LockedFinishState()
        writer.finishWriting {
            finishState.set(error: writerBox.writer.error)
            semaphore.signal()
        }
        semaphore.wait()

        if let finishError = finishState.error {
            throw RotatingCubeVideoExporterError.writerFailed(finishError.localizedDescription)
        }
    }

    private func makeVideoSettings(output: OutputSettings) -> [String: Any] {
        var compressionProperties: [String: Any] = [
            AVVideoAverageBitRateKey: output.averageBitRate,
        ]

        switch output.codec {
        case .h264:
            compressionProperties[AVVideoProfileLevelKey] = AVVideoProfileLevelH264HighAutoLevel
        case .hevc:
            compressionProperties[AVVideoProfileLevelKey] = kVTProfileLevel_HEVC_Main_AutoLevel
        }

        return [
            AVVideoCodecKey: output.codec.avFoundationCodec.rawValue,
            AVVideoWidthKey: output.width,
            AVVideoHeightKey: output.height,
            AVVideoCompressionPropertiesKey: compressionProperties,
        ]
    }

    private func makeMetalTexture(
        pixelBuffer: CVPixelBuffer,
        width: Int,
        height: Int
    ) -> MTLTexture? {
        var cvTexture: CVMetalTexture?
        CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            textureCache,
            pixelBuffer,
            nil,
            .bgra8Unorm,
            width,
            height,
            0,
            &cvTexture
        )

        guard let cvTexture else {
            return nil
        }

        return CVMetalTextureGetTexture(cvTexture)
    }
}

private final class LockedFinishState: @unchecked Sendable {
    private let lock = NSLock()
    private var storedError: Error?

    var error: Error? {
        lock.lock()
        defer { lock.unlock() }
        return storedError
    }

    func set(error: Error?) {
        lock.lock()
        storedError = error
        lock.unlock()
    }
}

private final class AssetWriterBox: @unchecked Sendable {
    let writer: AVAssetWriter

    init(_ writer: AVAssetWriter) {
        self.writer = writer
    }
}

private extension VideoCodec {
    var avFoundationCodec: AVVideoCodecType {
        switch self {
        case .h264:
            return .h264
        case .hevc:
            return .hevc
        }
    }
}
