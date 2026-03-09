import AppKit
import RotatingCubeCore
import ScreenSaver

@objc(RotatingCubeScreenSaverView)
final class RotatingCubeScreenSaverView: ScreenSaverView {
    private var metalView: RotatingCubeMetalView?

    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        animationTimeInterval = 1.0 / Double(SceneSpec.defaultWallpaper.loop.outputFPS)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        setupMetalView()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var hasConfigureSheet: Bool {
        false
    }

    override func startAnimation() {
        super.startAnimation()
        metalView?.isPaused = false
        metalView?.renderer.resetAnimationStartTime()
    }

    override func stopAnimation() {
        metalView?.isPaused = true
        super.stopAnimation()
    }

    override func layout() {
        super.layout()
        metalView?.frame = bounds
    }

    private func setupMetalView() {
        do {
            let view = try RotatingCubeMetalView(
                frame: bounds,
                sceneSpec: .defaultWallpaper,
                shaderBundle: Bundle(for: RotatingCubeScreenSaverView.self)
            )
            view.autoresizingMask = [.width, .height]
            addSubview(view)
            metalView = view
        } catch {
            let fallback = NSTextField(labelWithString: error.localizedDescription)
            fallback.frame = bounds
            fallback.alignment = .center
            fallback.textColor = .white
            fallback.backgroundColor = .clear
            fallback.autoresizingMask = [.width, .height]
            addSubview(fallback)
        }
    }
}
