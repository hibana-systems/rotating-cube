import AppKit
import MetalKit

public enum RotatingCubeMetalViewError: Error {
    case metalUnavailable
}

public final class RotatingCubeMetalView: MTKView {
    public let renderer: RotatingCubeMetalRenderer

    @MainActor
    public init(
        frame: CGRect = .zero,
        sceneSpec: SceneSpec = .defaultWallpaper,
        shaderBundle: Bundle
    ) throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw RotatingCubeMetalViewError.metalUnavailable
        }

        self.renderer = try RotatingCubeMetalRenderer(
            device: device,
            sceneSpec: sceneSpec,
            shaderBundle: shaderBundle
        )
        super.init(frame: frame, device: device)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        renderer.configure(view: self)
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
