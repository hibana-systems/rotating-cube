import RotatingCubeKit
import SwiftUI

struct ContentView: View {
    private let spec = CubeSceneSpec.defaultScene

    var body: some View {
        ZStack {
            TransparentBackdropView()

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

private struct TransparentBackdropView: View {
    var body: some View {
        ZStack {
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)

            LinearGradient(
                colors: [
                    Color.black.opacity(0.34),
                    Color.black.opacity(0.18),
                    Color.black.opacity(0.28),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [
                    Color(red: 0.20, green: 1.00, blue: 0.58).opacity(0.12),
                    .clear,
                ],
                center: UnitPoint(x: 0.5, y: 0.42),
                startRadius: 36,
                endRadius: 340
            )
        }
        .ignoresSafeArea()
    }
}
