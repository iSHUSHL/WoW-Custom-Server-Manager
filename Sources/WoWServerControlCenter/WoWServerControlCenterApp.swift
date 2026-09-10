import SwiftUI

@main
struct WoWServerControlCenterApp: App {
    @StateObject private var model = ServerModel()

    var body: some Scene {
        WindowGroup("WoW Server Control Center") {
            ContentView()
                .environmentObject(model)
                .wowccPremiumTheme()
                .frame(minWidth: 1080, minHeight: 680)
        }
        .defaultSize(width: 1320, height: 860)
        .windowStyle(.hiddenTitleBar)
    }
}
