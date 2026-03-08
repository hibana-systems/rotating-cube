import AppKit
import RotatingCubeCore
import SwiftUI

struct MetalPreviewView: NSViewRepresentable {
    let sceneSpec: SceneSpec

    func makeNSView(context: Context) -> NSView {
        do {
            let view = try RotatingCubeMetalView(
                sceneSpec: sceneSpec,
                shaderBundle: .main
            )
            view.autoresizingMask = [.width, .height]
            return view
        } catch {
            let fallback = NSTextField(labelWithString: error.localizedDescription)
            fallback.alignment = .center
            fallback.textColor = .white
            fallback.backgroundColor = .clear
            return fallback
        }
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
