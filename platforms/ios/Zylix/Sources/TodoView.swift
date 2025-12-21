//
//  TodoView.swift
//  Zylix
//
//  TodoMVC implementation with SwiftUI.
//

import SwiftUI

struct TodoView: View {
    @StateObject private var viewModel = TodoViewModel()
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header with input
                headerSection

                if !viewModel.items.isEmpty {
                    // Toggle all + List
                    mainSection

                    // Footer with counts and filters
                    footerSection
                } else {
                    emptyState
                }
            }
            .navigationTitle("todos")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack(spacing: 12) {
            TextField("What needs to be done?", text: $viewModel.newTodoText)
                .textFieldStyle(.plain)
                .font(.body)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .focused($isInputFocused)
                .onSubmit {
                    viewModel.addTodo()
                }

            Button {
                viewModel.addTodo()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
            }
            .disabled(viewModel.newTodoText.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding()
        .background(Color(.systemBackground))
    }

    // MARK: - Main Section

    private var mainSection: some View {
        VStack(spacing: 0) {
            // Toggle All
            HStack {
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        viewModel.toggleAll()
                    }
                } label: {
                    Image(systemName: viewModel.allCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(viewModel.allCompleted ? .green : .secondary)
                }
                .buttonStyle(.plain)

                Text("Mark all as \(viewModel.allCompleted ? "active" : "completed")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            // Todo List
            List {
                ForEach(viewModel.filteredItems) { item in
                    TodoItemRow(item: item, viewModel: viewModel)
                }
                .onDelete { indexSet in
                    let items = viewModel.filteredItems
                    for index in indexSet {
                        viewModel.remove(items[index])
                    }
                }
            }
            .listStyle(.plain)
        }
    }

    // MARK: - Footer Section

    private var footerSection: some View {
        VStack(spacing: 12) {
            Divider()

            HStack {
                // Item count
                Text(viewModel.itemsLeftText)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                // Filter buttons
                HStack(spacing: 8) {
                    ForEach(FilterMode.allCases, id: \.self) { mode in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModel.filter = mode
                            }
                        } label: {
                            Text(mode.rawValue)
                                .font(.caption)
                                .fontWeight(viewModel.filter == mode ? .semibold : .regular)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    viewModel.filter == mode
                                        ? Color.blue.opacity(0.1)
                                        : Color.clear
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(viewModel.filter == mode ? .blue : .secondary)
                    }
                }

                Spacer()

                // Clear completed
                if viewModel.completedCount > 0 {
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            viewModel.clearCompleted()
                        }
                    } label: {
                        Text("Clear completed")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "checklist")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("No todos yet")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Add your first todo above")
                .font(.subheadline)
                .foregroundStyle(.tertiary)

            Spacer()
        }
    }
}

// MARK: - Todo Item Row

struct TodoItemRow: View {
    let item: TodoItem
    @ObservedObject var viewModel: TodoViewModel
    @State private var isEditing = false
    @State private var editText = ""

    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            Button {
                withAnimation(.spring(response: 0.3)) {
                    viewModel.toggle(item)
                }
            } label: {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(item.isCompleted ? .green : .secondary)
            }
            .buttonStyle(.plain)

            // Text or Edit Field
            if isEditing {
                TextField("Todo", text: $editText)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        viewModel.updateText(item, newText: editText)
                        isEditing = false
                    }
            } else {
                Text(item.text)
                    .strikethrough(item.isCompleted, color: .secondary)
                    .foregroundStyle(item.isCompleted ? .secondary : .primary)
                    .contentTransition(.opacity)
                    .onTapGesture(count: 2) {
                        editText = item.text
                        isEditing = true
                    }
            }

            Spacer()

            // Delete button
            Button {
                withAnimation(.spring(response: 0.3)) {
                    viewModel.remove(item)
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.red.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    TodoView()
}
