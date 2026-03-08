import RotatingCubeKit
import SwiftUI

enum RenderBackend {
    case sceneKit
}

struct RendererHostView: View {
    let spec: CubeSceneSpec
    let backend: RenderBackend

    var body: some View {
        switch backend {
        case .sceneKit:
            SceneKitRendererView(spec: spec)
        }
    }
}
