import SwiftUI

@main
struct ZylixApp: App {
    @StateObject private var bridge = ZylixBridge.shared

    init() {
        // Initialize Zylix Core
        ZylixBridge.shared.initialize()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(bridge)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 400, height: 500)
    }
}
