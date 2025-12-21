//
//  TodoViewModel.swift
//  Zylix
//
//  Todo state management using pure Swift.
//  Future: Integrate with Zylix Core via C FFI.
//

import Foundation
import SwiftUI

// MARK: - Todo Item

struct TodoItem: Identifiable, Equatable {
    let id: UUID
    var text: String
    var isCompleted: Bool

    init(text: String, isCompleted: Bool = false) {
        self.id = UUID()
        self.text = text
        self.isCompleted = isCompleted
    }
}

// MARK: - Filter Mode

enum FilterMode: String, CaseIterable {
    case all = "All"
    case active = "Active"
    case completed = "Completed"
}

// MARK: - Todo View Model

@MainActor
final class TodoViewModel: ObservableObject {
    @Published var items: [TodoItem] = []
    @Published var filter: FilterMode = .all
    @Published var newTodoText: String = ""
    @Published var editingItem: TodoItem?

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

    var itemsLeftText: String {
        let count = activeCount
        return count == 1 ? "1 item left" : "\(count) items left"
    }

    // MARK: - Actions

    func addTodo() {
        let trimmed = newTodoText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let item = TodoItem(text: trimmed)
        items.append(item)
        newTodoText = ""
    }

    func toggle(_ item: TodoItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isCompleted.toggle()
    }

    func remove(_ item: TodoItem) {
        items.removeAll { $0.id == item.id }
    }

    func toggleAll() {
        let newState = !allCompleted
        for index in items.indices {
            items[index].isCompleted = newState
        }
    }

    func clearCompleted() {
        items.removeAll { $0.isCompleted }
    }

    func updateText(_ item: TodoItem, newText: String) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        let trimmed = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            items.remove(at: index)
        } else {
            items[index].text = trimmed
        }
    }
}
