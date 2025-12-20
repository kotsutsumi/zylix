//
//  ZylixApp.swift
//  Zylix macOS
//
//  Main app entry point for macOS Todo demo.
//

import SwiftUI

@main
struct ZylixApp: App {

    var body: some Scene {
        WindowGroup {
            TodoView()
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 450, height: 550)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}
