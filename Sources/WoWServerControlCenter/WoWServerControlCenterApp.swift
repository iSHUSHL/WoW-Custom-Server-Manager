import SwiftUI

@main
struct WoWServerControlCenterApp: App {
    @StateObject private var model = ServerModel()

    var body: some Scene {
        WindowGroup("WoW Server Control Center") {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 960, minHeight: 600)
        }
        .defaultSize(width: 1220, height: 780)
        .windowStyle(.hiddenTitleBar)
    }
}
