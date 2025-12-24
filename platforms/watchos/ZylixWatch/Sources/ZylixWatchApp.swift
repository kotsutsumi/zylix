//
//  ZylixWatchApp.swift
//  ZylixWatch
//
//  Main application entry point for watchOS.
//

import SwiftUI

@main
struct ZylixWatchApp: App {
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
