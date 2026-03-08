import RotatingCubeKit
import SceneKit
import SwiftUI

struct SceneKitRendererView: NSViewRepresentable {
    let spec: CubeSceneSpec

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> SCNView {
        let view = SCNView(frame: .zero)
        view.backgroundColor = .clear
        view.antialiasingMode = .multisampling4X
        view.allowsCameraControl = false
        view.autoenablesDefaultLighting = false
        view.preferredFramesPerSecond = 20
        view.rendersContinuously = true
        view.isPlaying = true
        updateScene(for: view, coordinator: context.coordinator)
        return view
    }

    func updateNSView(_ nsView: SCNView, context: Context) {
        updateScene(for: nsView, coordinator: context.coordinator)
    }

    private func updateScene(for view: SCNView, coordinator: Coordinator) {
        guard coordinator.renderedSpec != spec else {
            return
        }

        let builtScene = SceneKitSceneBuilder.build(spec: spec)
        view.scene = builtScene.scene
        view.pointOfView = builtScene.pointOfView
        coordinator.renderedSpec = spec
    }

    final class Coordinator {
        var renderedSpec: CubeSceneSpec?
    }
}
