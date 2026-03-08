import RotatingCubeCore
import SwiftUI

struct ContentView: View {
    let sceneSpec: SceneSpec

    var body: some View {
        ZStack {
            Color.black

            MetalPreviewView(sceneSpec: sceneSpec)
                .ignoresSafeArea()
        }
        .frame(minWidth: 960, minHeight: 540)
        .background(
            OpaqueWindowConfigurator()
                .frame(width: 0, height: 0)
        )
    }
}
