import Foundation
import Metal
import MetalKit
import QuartzCore
import simd

public enum RotatingCubeMetalRendererError: Error {
    case commandQueueUnavailable
    case libraryUnavailable
    case pipelineCreationFailed(String)
}

public final class RotatingCubeMetalRenderer: NSObject, MTKViewDelegate {
    public let device: MTLDevice
    public let sceneSpec: SceneSpec
    public let timeline: RendererTimeline

    private let shaderBundle: Bundle
    private let commandQueue: MTLCommandQueue
    private let library: MTLLibrary
    private let linePipelineState: MTLRenderPipelineState
    private let brightPassPipelineState: MTLRenderPipelineState
    private let blurPipelineState: MTLRenderPipelineState
    private let compositePipelineState: MTLRenderPipelineState
    private let linearSamplerState: MTLSamplerState

    private var viewportSize = CGSize(width: 1, height: 1)
    private var sceneTexture: MTLTexture?
    private var bloomTextureA: MTLTexture?
    private var bloomTextureB: MTLTexture?
    private var animationStartTime = CACurrentMediaTime()

    public init(
        device: MTLDevice,
        sceneSpec: SceneSpec = .defaultWallpaper,
        shaderBundle: Bundle
    ) throws {
        self.device = device
        self.sceneSpec = sceneSpec
        self.timeline = RendererTimeline(loop: sceneSpec.loop)
        self.shaderBundle = shaderBundle

        guard let commandQueue = device.makeCommandQueue() else {
            throw RotatingCubeMetalRendererError.commandQueueUnavailable
        }

        self.commandQueue = commandQueue

        guard let library = try? device.makeDefaultLibrary(bundle: shaderBundle) else {
            throw RotatingCubeMetalRendererError.libraryUnavailable
        }

        self.library = library
        self.linePipelineState = try RotatingCubeMetalRenderer.makeLinePipeline(
            device: device,
            library: library
        )
        self.brightPassPipelineState = try RotatingCubeMetalRenderer.makeFullscreenPipeline(
            device: device,
            library: library,
            fragmentFunctionName: "brightPassFragment",
            pixelFormat: .rgba16Float
        )
        self.blurPipelineState = try RotatingCubeMetalRenderer.makeFullscreenPipeline(
            device: device,
            library: library,
            fragmentFunctionName: "gaussianBlurFragment",
            pixelFormat: .rgba16Float
        )
        self.compositePipelineState = try RotatingCubeMetalRenderer.makeFullscreenPipeline(
            device: device,
            library: library,
            fragmentFunctionName: "crtCompositeFragment",
            pixelFormat: .bgra8Unorm
        )
        self.linearSamplerState = RotatingCubeMetalRenderer.makeLinearSampler(device: device)

        super.init()
    }

    @MainActor
    public func configure(view: MTKView) {
        view.device = device
        view.colorPixelFormat = .bgra8Unorm
        view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        view.preferredFramesPerSecond = sceneSpec.loop.outputFPS
        view.enableSetNeedsDisplay = false
        view.isPaused = false
        view.framebufferOnly = false
        view.sampleCount = 1
        view.delegate = self
        updateRenderTargets(for: view.drawableSize)
    }

    public func resetAnimationStartTime() {
        animationStartTime = CACurrentMediaTime()
    }

    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        updateRenderTargets(for: size)
    }

    public func draw(in view: MTKView) {
        guard
            let drawable = view.currentDrawable,
            let commandBuffer = commandQueue.makeCommandBuffer()
        else {
            return
        }

        let elapsedTime = CACurrentMediaTime() - animationStartTime
        let sampledTime = timeline.sampledTime(forElapsedTime: elapsedTime)
        renderFrame(
            sampledTime: sampledTime,
            destinationTexture: drawable.texture,
            destinationSize: view.drawableSize,
            commandBuffer: commandBuffer
        )
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    public func renderPresentationFrame(
        index: Int,
        destinationTexture: MTLTexture,
        destinationSize: CGSize,
        commandBuffer: MTLCommandBuffer,
        timeline overrideTimeline: RendererTimeline? = nil
    ) {
        let activeTimeline = overrideTimeline ?? timeline
        let sampledTime = activeTimeline.sampledTime(forPresentationFrame: index)
        renderFrame(
            sampledTime: sampledTime,
            destinationTexture: destinationTexture,
            destinationSize: destinationSize,
            commandBuffer: commandBuffer
        )
    }

    private func renderFrame(
        sampledTime: Double,
        destinationTexture: MTLTexture,
        destinationSize: CGSize,
        commandBuffer: MTLCommandBuffer
    ) {
        updateRenderTargets(for: destinationSize)
        guard
            let sceneTexture,
            let bloomTextureA,
            let bloomTextureB
        else {
            return
        }

        let linePrimitives = SceneGeometryBuilder.buildLinePrimitives(
            spec: sceneSpec,
            time: sampledTime
        )
        let lineInstances = linePrimitives.map {
            GPUSceneLineInstance(
                startPosition: $0.start,
                endPosition: $0.end,
                coreStartColor: $0.coreStartColor,
                coreEndColor: $0.coreEndColor,
                glowStartColor: $0.glowStartColor,
                glowEndColor: $0.glowEndColor,
                coreWidth: $0.coreWidthPixels,
                glowWidth: $0.glowWidthPixels
            )
        }

        guard
            !lineInstances.isEmpty,
            let lineBuffer = device.makeBuffer(
                bytes: lineInstances,
                length: MemoryLayout<GPUSceneLineInstance>.stride * lineInstances.count,
                options: .storageModeShared
            )
        else {
            return
        }

        let viewProjectionMatrix = makeViewProjectionMatrix(
            size: destinationSize,
            camera: sceneSpec.camera
        )
        var lineUniforms = GPULineVertexUniforms(
            viewProjectionMatrix: viewProjectionMatrix,
            viewportSize: SIMD2<Float>(
                Float(max(destinationSize.width, 1)),
                Float(max(destinationSize.height, 1))
            )
        )
        var glowPassUniforms = GPULinePassUniforms(
            passKind: 1,
            aaEnabled: sceneSpec.antiAliasing.isEnabled ? 1 : 0,
            edgeFeatherWidth: sceneSpec.antiAliasing.edgeFeatherWidth,
            edgeSoftness: sceneSpec.antiAliasing.edgeSoftness
        )
        var corePassUniforms = GPULinePassUniforms(
            passKind: 0,
            aaEnabled: sceneSpec.antiAliasing.isEnabled ? 1 : 0,
            edgeFeatherWidth: sceneSpec.antiAliasing.edgeFeatherWidth,
            edgeSoftness: sceneSpec.antiAliasing.edgeSoftness
        )

        let scenePassDescriptor = MTLRenderPassDescriptor()
        scenePassDescriptor.colorAttachments[0].texture = sceneTexture
        scenePassDescriptor.colorAttachments[0].loadAction = .clear
        scenePassDescriptor.colorAttachments[0].storeAction = .store
        scenePassDescriptor.colorAttachments[0].clearColor = MTLClearColor(
            red: 0,
            green: 0,
            blue: 0,
            alpha: 1
        )

        if let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: scenePassDescriptor) {
            encoder.setRenderPipelineState(linePipelineState)
            encoder.setCullMode(.none)
            encoder.setVertexBuffer(lineBuffer, offset: 0, index: 0)
            encoder.setVertexBytes(
                &lineUniforms,
                length: MemoryLayout<GPULineVertexUniforms>.stride,
                index: 1
            )

            encoder.setFragmentBytes(
                &glowPassUniforms,
                length: MemoryLayout<GPULinePassUniforms>.stride,
                index: 0
            )
            encoder.setVertexBytes(
                &glowPassUniforms,
                length: MemoryLayout<GPULinePassUniforms>.stride,
                index: 2
            )
            encoder.drawPrimitives(
                type: .triangleStrip,
                vertexStart: 0,
                vertexCount: 4,
                instanceCount: lineInstances.count
            )

            encoder.setFragmentBytes(
                &corePassUniforms,
                length: MemoryLayout<GPULinePassUniforms>.stride,
                index: 0
            )
            encoder.setVertexBytes(
                &corePassUniforms,
                length: MemoryLayout<GPULinePassUniforms>.stride,
                index: 2
            )
            encoder.drawPrimitives(
                type: .triangleStrip,
                vertexStart: 0,
                vertexCount: 4,
                instanceCount: lineInstances.count
            )

            encoder.endEncoding()
        }

        var brightUniforms = GPUBrightPassUniforms(
            bloomThreshold: sceneSpec.crt.bloomThreshold
        )
        encodeFullscreenPass(
            commandBuffer: commandBuffer,
            texture: bloomTextureA,
            pipelineState: brightPassPipelineState,
            sourceTexture: sceneTexture,
            sourceTextureTwo: nil,
            fragmentBytes: &brightUniforms,
            fragmentBytesLength: MemoryLayout<GPUBrightPassUniforms>.stride
        )

        var horizontalBlur = GPUBlurUniforms(
            direction: SIMD2<Float>(1, 0),
            sourceTexelSize: SIMD2<Float>(
                1 / Float(max(bloomTextureA.width, 1)),
                1 / Float(max(bloomTextureA.height, 1))
            )
        )
        encodeFullscreenPass(
            commandBuffer: commandBuffer,
            texture: bloomTextureB,
            pipelineState: blurPipelineState,
            sourceTexture: bloomTextureA,
            sourceTextureTwo: nil,
            fragmentBytes: &horizontalBlur,
            fragmentBytesLength: MemoryLayout<GPUBlurUniforms>.stride
        )

        var verticalBlur = GPUBlurUniforms(
            direction: SIMD2<Float>(0, 1),
            sourceTexelSize: SIMD2<Float>(
                1 / Float(max(bloomTextureB.width, 1)),
                1 / Float(max(bloomTextureB.height, 1))
            )
        )
        encodeFullscreenPass(
            commandBuffer: commandBuffer,
            texture: bloomTextureA,
            pipelineState: blurPipelineState,
            sourceTexture: bloomTextureB,
            sourceTextureTwo: nil,
            fragmentBytes: &verticalBlur,
            fragmentBytesLength: MemoryLayout<GPUBlurUniforms>.stride
        )

        var compositeUniforms = GPUCompositeUniforms(
            resolution: SIMD2<Float>(
                Float(max(destinationSize.width, 1)),
                Float(max(destinationSize.height, 1))
            ),
            bloomIntensity: sceneSpec.crt.bloomIntensity,
            scanlineIntensity: sceneSpec.crt.scanlineIntensity,
            scanlineDensity: sceneSpec.crt.scanlineDensity,
            phosphorMaskIntensity: sceneSpec.crt.phosphorMaskIntensity,
            vignetteIntensity: sceneSpec.crt.vignetteIntensity,
            barrelDistortion: sceneSpec.crt.barrelDistortion,
            cornerPinch: sceneSpec.crt.cornerPinch,
            time: Float(sampledTime)
        )
        encodeFullscreenPass(
            commandBuffer: commandBuffer,
            texture: destinationTexture,
            pipelineState: compositePipelineState,
            sourceTexture: sceneTexture,
            sourceTextureTwo: bloomTextureA,
            fragmentBytes: &compositeUniforms,
            fragmentBytesLength: MemoryLayout<GPUCompositeUniforms>.stride
        )
    }

    private func encodeFullscreenPass<T>(
        commandBuffer: MTLCommandBuffer,
        texture: MTLTexture,
        pipelineState: MTLRenderPipelineState,
        sourceTexture: MTLTexture,
        sourceTextureTwo: MTLTexture?,
        fragmentBytes: inout T,
        fragmentBytesLength: Int
    ) {
        let descriptor = MTLRenderPassDescriptor()
        descriptor.colorAttachments[0].texture = texture
        descriptor.colorAttachments[0].loadAction = .clear
        descriptor.colorAttachments[0].storeAction = .store
        descriptor.colorAttachments[0].clearColor = MTLClearColor(
            red: 0,
            green: 0,
            blue: 0,
            alpha: 1
        )

        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
            return
        }

        encoder.setRenderPipelineState(pipelineState)
        encoder.setFragmentSamplerState(linearSamplerState, index: 0)
        encoder.setFragmentTexture(sourceTexture, index: 0)

        if let sourceTextureTwo {
            encoder.setFragmentTexture(sourceTextureTwo, index: 1)
        }

        withUnsafeBytes(of: &fragmentBytes) { rawBytes in
            guard let baseAddress = rawBytes.baseAddress else {
                return
            }

            encoder.setFragmentBytes(
                baseAddress,
                length: fragmentBytesLength,
                index: 0
            )
        }
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
    }

    private func updateRenderTargets(for size: CGSize) {
        guard size.width > 0, size.height > 0 else {
            return
        }

        if size == viewportSize, sceneTexture != nil, bloomTextureA != nil, bloomTextureB != nil {
            return
        }

        viewportSize = size
        let width = max(Int(size.width.rounded(.up)), 1)
        let height = max(Int(size.height.rounded(.up)), 1)
        let bloomWidth = max(width / 2, 1)
        let bloomHeight = max(height / 2, 1)

        sceneTexture = makeTexture(
            width: width,
            height: height,
            pixelFormat: .rgba16Float
        )
        bloomTextureA = makeTexture(
            width: bloomWidth,
            height: bloomHeight,
            pixelFormat: .rgba16Float
        )
        bloomTextureB = makeTexture(
            width: bloomWidth,
            height: bloomHeight,
            pixelFormat: .rgba16Float
        )
    }

    private func makeTexture(
        width: Int,
        height: Int,
        pixelFormat: MTLPixelFormat
    ) -> MTLTexture? {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: pixelFormat,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.storageMode = .private
        descriptor.usage = [.shaderRead, .renderTarget]
        return device.makeTexture(descriptor: descriptor)
    }

    private func makeViewProjectionMatrix(
        size: CGSize,
        camera: CameraSettings
    ) -> simd_float4x4 {
        let aspectRatio = Float(max(size.width / max(size.height, 1), 0.0001))
        let projection = MatrixMath.perspective(
            fieldOfViewDegrees: camera.fieldOfViewDegrees,
            aspectRatio: aspectRatio,
            nearPlane: camera.nearPlane,
            farPlane: camera.farPlane
        )
        let view = MatrixMath.lookAt(
            eye: camera.position,
            target: camera.target
        )
        return projection * view
    }

    private static func makeLinePipeline(
        device: MTLDevice,
        library: MTLLibrary
    ) throws -> MTLRenderPipelineState {
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "lineVertex")
        descriptor.fragmentFunction = library.makeFunction(name: "lineFragment")
        descriptor.colorAttachments[0].pixelFormat = .rgba16Float
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .one
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        descriptor.colorAttachments[0].rgbBlendOperation = .add
        descriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
        descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        descriptor.colorAttachments[0].alphaBlendOperation = .add

        return try device.makeRenderPipelineState(descriptor: descriptor)
    }

    private static func makeFullscreenPipeline(
        device: MTLDevice,
        library: MTLLibrary,
        fragmentFunctionName: String,
        pixelFormat: MTLPixelFormat
    ) throws -> MTLRenderPipelineState {
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "fullscreenVertex")
        descriptor.fragmentFunction = library.makeFunction(name: fragmentFunctionName)
        descriptor.colorAttachments[0].pixelFormat = pixelFormat
        return try device.makeRenderPipelineState(descriptor: descriptor)
    }

    private static func makeLinearSampler(device: MTLDevice) -> MTLSamplerState {
        let descriptor = MTLSamplerDescriptor()
        descriptor.minFilter = .linear
        descriptor.magFilter = .linear
        descriptor.sAddressMode = .clampToZero
        descriptor.tAddressMode = .clampToZero
        return device.makeSamplerState(descriptor: descriptor)!
    }
}
