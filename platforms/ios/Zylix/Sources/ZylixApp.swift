//
//  ZylixApp.swift
//  Zylix
//
//  Main application entry point.
//

import SwiftUI

@main
struct ZylixApp: App {
    @StateObject private var bridge = ZylixBridge.shared

    init() {
        // Initialize Zylix Core on app launch
        Task { @MainActor in
            ZylixBridge.shared.initialize()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(bridge)
        }
    }
}
