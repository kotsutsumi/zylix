//
//  TodoViewModel.swift
//  Zylix macOS
//
//  ViewModel for the Todo app demo.
//  Pure Swift implementation with future Zylix Core integration.
//

import SwiftUI
import Combine

// MARK: - Todo Item Model

/// Represents a single todo item
struct TodoItem: Identifiable, Equatable {
    let id: UInt32
    var text: String
    var isCompleted: Bool
}

// MARK: - Filter Mode

enum TodoFilter: String, CaseIterable {
    case all = "All"
    case active = "Active"
    case completed = "Completed"
}

// MARK: - Event Types

/// Event type identifiers matching the Zig implementation
enum TodoEventType: UInt32 {
    case add = 0x3000
    case remove = 0x3001
    case toggle = 0x3002
    case toggleAll = 0x3003
    case clearCompleted = 0x3004
    case setFilter = 0x3005
}

// MARK: - Todo ViewModel

/// ViewModel for the Todo app
@MainActor
class TodoViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var items: [TodoItem] = []
    @Published var newTodoText: String = ""
    @Published var filter: TodoFilter = .all

    // MARK: - Computed Properties

    var filteredItems: [TodoItem] {
        switch filter {
        case .all:
            return items
        case .active:
            return items.filter { !$0.isCompleted }
        case .completed:
            return items.filter { $0.isCompleted }
        }
    }

    var activeCount: Int {
        items.filter { !$0.isCompleted }.count
    }

    var completedCount: Int {
        items.filter { $0.isCompleted }.count
    }

    var allCompleted: Bool {
        !items.isEmpty && items.allSatisfy { $0.isCompleted }
    }

    // MARK: - State Tracking

    private var nextId: UInt32 = 1
    @Published var renderCount: Int = 0
    @Published var lastRenderTime: Double = 0

    // MARK: - Initialization

    init() {
        // Add some sample todos for demo
        addTodo("Learn Zig")
        addTodo("Build VDOM")
        addTodo("Create macOS bindings")
    }

    // MARK: - Actions

    func addTodo(_ text: String? = nil) {
        let todoText = text ?? newTodoText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !todoText.isEmpty else { return }

        let startTime = CFAbsoluteTimeGetCurrent()

        let item = TodoItem(id: nextId, text: todoText, isCompleted: false)
        items.append(item)
        nextId += 1

        if text == nil {
            newTodoText = ""
        }

        trackRender(startTime: startTime)
    }

    func removeTodo(_ item: TodoItem) {
        let startTime = CFAbsoluteTimeGetCurrent()
        items.removeAll { $0.id == item.id }
        trackRender(startTime: startTime)
    }

    func toggleTodo(_ item: TodoItem) {
        let startTime = CFAbsoluteTimeGetCurrent()

        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].isCompleted.toggle()
        }

        trackRender(startTime: startTime)
    }

    func toggleAll() {
        let startTime = CFAbsoluteTimeGetCurrent()

        let shouldComplete = !allCompleted
        for index in items.indices {
            items[index].isCompleted = shouldComplete
        }

        trackRender(startTime: startTime)
    }

    func clearCompleted() {
        let startTime = CFAbsoluteTimeGetCurrent()
        items.removeAll { $0.isCompleted }
        trackRender(startTime: startTime)
    }

    private func trackRender(startTime: CFAbsoluteTime) {
        let endTime = CFAbsoluteTimeGetCurrent()
        lastRenderTime = (endTime - startTime) * 1000 // Convert to ms
        renderCount += 1
    }
}
