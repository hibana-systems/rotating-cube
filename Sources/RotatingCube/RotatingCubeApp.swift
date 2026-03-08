import AppKit
import RotatingCubeKit
import SwiftUI

@main
struct RotatingCubeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Window("Rotating Cube", id: "main-window") {
            ContentView()
        }
        .defaultSize(width: 1040, height: 760)

        Settings {
            EmptyView()
        }
    }
}
