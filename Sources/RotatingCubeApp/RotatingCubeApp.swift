import RotatingCubeCore
import SwiftUI

@main
struct RotatingCubeApp: App {
    var body: some Scene {
        Window("Rotating Cube", id: "main-window") {
            ContentView(sceneSpec: .defaultWallpaper)
        }
        .defaultSize(width: 1280, height: 720)

        Settings {
            EmptyView()
        }
    }
}
