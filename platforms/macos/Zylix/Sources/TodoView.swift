//
//  TodoView.swift
//  Zylix macOS
//
//  SwiftUI Todo app view for macOS.
//

import SwiftUI

struct TodoView: View {
    @StateObject private var viewModel = TodoViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            // Input field
            inputField

            // Filter tabs
            filterTabs

            // Todo list
            todoList

            // Footer
            footerView

            // Stats panel
            statsPanel
        }
        .frame(minWidth: 400, idealWidth: 500, minHeight: 500, idealHeight: 600)
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: 4) {
            Text("Zylix Todo")
                .font(.title)
                .fontWeight(.semibold)

            Text("ZigDom + Swift (macOS)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Input Field

    private var inputField: some View {
        HStack(spacing: 12) {
            // Toggle all button
            Button(action: viewModel.toggleAll) {
                Image(systemName: viewModel.allCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(viewModel.allCompleted ? .accentColor : .gray)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.items.isEmpty)

            // Text field
            TextField("What needs to be done?", text: $viewModel.newTodoText)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    viewModel.addTodo()
                }

            // Add button
            Button(action: { viewModel.addTodo() }) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.newTodoText.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Filter Tabs

    private var filterTabs: some View {
        HStack(spacing: 0) {
            ForEach(TodoFilter.allCases, id: \.self) { filter in
                Button(action: { viewModel.filter = filter }) {
                    Text(filter.rawValue)
                        .font(.subheadline)
                        .fontWeight(viewModel.filter == filter ? .semibold : .regular)
                        .foregroundColor(viewModel.filter == filter ? .accentColor : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            viewModel.filter == filter ?
                            Color.accentColor.opacity(0.1) :
                            Color.clear
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(NSColor.separatorColor)),
            alignment: .bottom
        )
    }

    // MARK: - Todo List

    private var todoList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.filteredItems) { item in
                    TodoRowView(
                        item: item,
                        onToggle: { viewModel.toggleTodo(item) },
                        onDelete: { viewModel.removeTodo(item) }
                    )
                    Divider()
                        .padding(.leading, 48)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.textBackgroundColor))
        .overlay {
            if viewModel.filteredItems.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checklist")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No Todos")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text(emptyMessage)
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.8))
                }
            }
        }
    }

    private var emptyMessage: String {
        switch viewModel.filter {
        case .all:
            return "Add a todo to get started"
        case .active:
            return "No active todos"
        case .completed:
            return "No completed todos"
        }
    }

    // MARK: - Footer

    private var footerView: some View {
        HStack {
            Text("\(viewModel.activeCount) item\(viewModel.activeCount == 1 ? "" : "s") left")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            if viewModel.completedCount > 0 {
                Button("Clear Completed") {
                    viewModel.clearCompleted()
                }
                .font(.caption)
                .foregroundColor(.red)
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Stats Panel

    private var statsPanel: some View {
        VStack(spacing: 8) {
            Divider()

            HStack(spacing: 30) {
                StatView(label: "Todos", value: "\(viewModel.items.count)")
                StatView(label: "Renders", value: "\(viewModel.renderCount)")
                StatView(label: "Render Time", value: String(format: "%.2f ms", viewModel.lastRenderTime))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - Todo Row View

struct TodoRowView: View {
    let item: TodoItem
    let onToggle: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            Button(action: onToggle) {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(item.isCompleted ? .green : .gray)
            }
            .buttonStyle(.plain)

            // Text
            Text(item.text)
                .strikethrough(item.isCompleted)
                .foregroundColor(item.isCompleted ? .secondary : .primary)

            Spacer()

            // Delete button (visible on hover)
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red.opacity(0.7))
            }
            .buttonStyle(.plain)
            .opacity(isHovered ? 1 : 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .background(isHovered ? Color(NSColor.selectedContentBackgroundColor).opacity(0.1) : Color.clear)
    }
}

// MARK: - Stat View

struct StatView: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
                .monospacedDigit()
                .foregroundColor(.primary)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Preview

#Preview {
    TodoView()
}
