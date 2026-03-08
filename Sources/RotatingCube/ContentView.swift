import RotatingCubeKit
import SwiftUI

struct ContentView: View {
    private let spec = CubeSceneSpec.defaultScene

    var body: some View {
        ZStack {
            Color.black

            RendererHostView(spec: spec, backend: .sceneKit)
                .padding(24)
                .allowsHitTesting(false)
        }
        .frame(minWidth: 820, minHeight: 560)
        .background(
            TransparentWindowConfigurator()
                .frame(width: 0, height: 0)
        )
    }
}
