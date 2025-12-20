import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = TodoViewModel()

    var body: some View {
        NavigationStack {
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
            .navigationTitle("Zylix Todo")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: 4) {
            Text("ZigDom + Swift")
                .font(.caption)
                .foregroundColor(.secondary)

            Text("Todo App Demo")
                .font(.headline)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
    }

    // MARK: - Input Field

    private var inputField: some View {
        HStack(spacing: 12) {
            // Toggle all button
            Button(action: viewModel.toggleAll) {
                Image(systemName: viewModel.allCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(viewModel.allCompleted ? .blue : .gray)
            }
            .disabled(viewModel.items.isEmpty)

            // Text field
            TextField("What needs to be done?", text: $viewModel.newTodoText)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.done)
                .onSubmit {
                    viewModel.addTodo()
                }

            // Add button
            Button(action: { viewModel.addTodo() }) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            .disabled(viewModel.newTodoText.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground))
    }

    // MARK: - Filter Tabs

    private var filterTabs: some View {
        HStack(spacing: 0) {
            ForEach(TodoFilter.allCases, id: \.self) { filter in
                Button(action: { viewModel.filter = filter }) {
                    Text(filter.rawValue)
                        .font(.subheadline)
                        .fontWeight(viewModel.filter == filter ? .semibold : .regular)
                        .foregroundColor(viewModel.filter == filter ? .blue : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
            }
        }
        .background(Color(.tertiarySystemBackground))
    }

    // MARK: - Todo List

    private var todoList: some View {
        List {
            ForEach(viewModel.filteredItems) { item in
                TodoRowView(
                    item: item,
                    onToggle: { viewModel.toggleTodo(item) },
                    onDelete: { viewModel.removeTodo(item) }
                )
            }
            .onDelete { indexSet in
                for index in indexSet {
                    let item = viewModel.filteredItems[index]
                    viewModel.removeTodo(item)
                }
            }
        }
        .listStyle(.plain)
        .overlay {
            if viewModel.filteredItems.isEmpty {
                ContentUnavailableView(
                    "No Todos",
                    systemImage: "checklist",
                    description: Text(emptyMessage)
                )
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
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground))
    }

    // MARK: - Stats Panel

    private var statsPanel: some View {
        VStack(spacing: 8) {
            Divider()

            HStack(spacing: 20) {
                StatView(label: "Todos", value: "\(viewModel.items.count)")
                StatView(label: "Renders", value: "\(viewModel.renderCount)")
                StatView(label: "Render Time", value: String(format: "%.2f ms", viewModel.lastRenderTime))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - Todo Row View

struct TodoRowView: View {
    let item: TodoItem
    let onToggle: () -> Void
    let onDelete: () -> Void

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

            // Delete button
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
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
                .foregroundColor(.primary)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
