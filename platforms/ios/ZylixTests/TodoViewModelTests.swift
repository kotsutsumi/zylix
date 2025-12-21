//
//  TodoViewModelTests.swift
//  ZylixTests
//
//  Comprehensive unit tests for TodoMVC state management.
//

import XCTest
@testable import Zylix

@MainActor
final class TodoViewModelTests: XCTestCase {

    var viewModel: TodoViewModel!

    override func setUp() async throws {
        viewModel = TodoViewModel()
    }

    override func tearDown() async throws {
        viewModel = nil
    }

    // MARK: - Initial State Tests

    func testInitialState() {
        XCTAssertTrue(viewModel.items.isEmpty, "Initial items should be empty")
        XCTAssertEqual(viewModel.filter, .all, "Initial filter should be .all")
        XCTAssertEqual(viewModel.newTodoText, "", "Initial newTodoText should be empty")
        XCTAssertNil(viewModel.editingItem, "Initial editingItem should be nil")
    }

    func testInitialComputedProperties() {
        XCTAssertTrue(viewModel.filteredItems.isEmpty, "Filtered items should be empty initially")
        XCTAssertEqual(viewModel.activeCount, 0, "Active count should be 0 initially")
        XCTAssertEqual(viewModel.completedCount, 0, "Completed count should be 0 initially")
        XCTAssertFalse(viewModel.allCompleted, "allCompleted should be false when empty")
        XCTAssertEqual(viewModel.itemsLeftText, "0 items left", "Items left text should show 0")
    }

    // MARK: - Add Todo Tests

    func testAddTodo() {
        viewModel.newTodoText = "Test todo"
        viewModel.addTodo()

        XCTAssertEqual(viewModel.items.count, 1, "Should have 1 item")
        XCTAssertEqual(viewModel.items[0].text, "Test todo", "Todo text should match")
        XCTAssertFalse(viewModel.items[0].isCompleted, "New todo should not be completed")
        XCTAssertEqual(viewModel.newTodoText, "", "newTodoText should be cleared")
    }

    func testAddTodoTrimsWhitespace() {
        viewModel.newTodoText = "  Trimmed todo  "
        viewModel.addTodo()

        XCTAssertEqual(viewModel.items[0].text, "Trimmed todo", "Todo text should be trimmed")
    }

    func testAddEmptyTodo() {
        viewModel.newTodoText = ""
        viewModel.addTodo()

        XCTAssertTrue(viewModel.items.isEmpty, "Empty text should not add todo")
    }

    func testAddWhitespaceOnlyTodo() {
        viewModel.newTodoText = "   "
        viewModel.addTodo()

        XCTAssertTrue(viewModel.items.isEmpty, "Whitespace-only text should not add todo")
    }

    func testAddMultipleTodos() {
        viewModel.newTodoText = "First"
        viewModel.addTodo()
        viewModel.newTodoText = "Second"
        viewModel.addTodo()
        viewModel.newTodoText = "Third"
        viewModel.addTodo()

        XCTAssertEqual(viewModel.items.count, 3, "Should have 3 items")
        XCTAssertEqual(viewModel.items[0].text, "First")
        XCTAssertEqual(viewModel.items[1].text, "Second")
        XCTAssertEqual(viewModel.items[2].text, "Third")
    }

    // MARK: - Toggle Tests

    func testToggleTodo() {
        viewModel.newTodoText = "Toggle me"
        viewModel.addTodo()
        let item = viewModel.items[0]

        viewModel.toggle(item)

        XCTAssertTrue(viewModel.items[0].isCompleted, "Todo should be completed after toggle")

        viewModel.toggle(viewModel.items[0])

        XCTAssertFalse(viewModel.items[0].isCompleted, "Todo should be active after second toggle")
    }

    func testToggleNonExistentItem() {
        let fakeItem = TodoItem(text: "Fake")
        viewModel.toggle(fakeItem)

        XCTAssertTrue(viewModel.items.isEmpty, "Should not crash on non-existent item")
    }

    // MARK: - Remove Tests

    func testRemoveTodo() {
        viewModel.newTodoText = "Remove me"
        viewModel.addTodo()
        let item = viewModel.items[0]

        viewModel.remove(item)

        XCTAssertTrue(viewModel.items.isEmpty, "Items should be empty after removal")
    }

    func testRemoveMiddleTodo() {
        viewModel.newTodoText = "First"
        viewModel.addTodo()
        viewModel.newTodoText = "Second"
        viewModel.addTodo()
        viewModel.newTodoText = "Third"
        viewModel.addTodo()

        let secondItem = viewModel.items[1]
        viewModel.remove(secondItem)

        XCTAssertEqual(viewModel.items.count, 2, "Should have 2 items")
        XCTAssertEqual(viewModel.items[0].text, "First")
        XCTAssertEqual(viewModel.items[1].text, "Third")
    }

    // MARK: - Toggle All Tests

    func testToggleAllComplete() {
        viewModel.newTodoText = "First"
        viewModel.addTodo()
        viewModel.newTodoText = "Second"
        viewModel.addTodo()

        viewModel.toggleAll()

        XCTAssertTrue(viewModel.items.allSatisfy { $0.isCompleted }, "All items should be completed")
        XCTAssertTrue(viewModel.allCompleted, "allCompleted should be true")
    }

    func testToggleAllActive() {
        viewModel.newTodoText = "First"
        viewModel.addTodo()
        viewModel.newTodoText = "Second"
        viewModel.addTodo()

        // Complete all
        viewModel.toggleAll()
        // Then activate all
        viewModel.toggleAll()

        XCTAssertTrue(viewModel.items.allSatisfy { !$0.isCompleted }, "All items should be active")
        XCTAssertFalse(viewModel.allCompleted, "allCompleted should be false")
    }

    func testToggleAllWithMixedState() {
        viewModel.newTodoText = "First"
        viewModel.addTodo()
        viewModel.newTodoText = "Second"
        viewModel.addTodo()

        // Complete first item only
        viewModel.toggle(viewModel.items[0])

        // Toggle all should complete all
        viewModel.toggleAll()

        XCTAssertTrue(viewModel.items.allSatisfy { $0.isCompleted }, "All items should be completed")
    }

    // MARK: - Clear Completed Tests

    func testClearCompleted() {
        viewModel.newTodoText = "Active"
        viewModel.addTodo()
        viewModel.newTodoText = "Completed"
        viewModel.addTodo()
        viewModel.toggle(viewModel.items[1])

        viewModel.clearCompleted()

        XCTAssertEqual(viewModel.items.count, 1, "Should have 1 item")
        XCTAssertEqual(viewModel.items[0].text, "Active")
    }

    func testClearCompletedWithNoCompleted() {
        viewModel.newTodoText = "Active"
        viewModel.addTodo()

        viewModel.clearCompleted()

        XCTAssertEqual(viewModel.items.count, 1, "Should still have 1 item")
    }

    func testClearAllCompleted() {
        viewModel.newTodoText = "First"
        viewModel.addTodo()
        viewModel.newTodoText = "Second"
        viewModel.addTodo()
        viewModel.toggleAll()

        viewModel.clearCompleted()

        XCTAssertTrue(viewModel.items.isEmpty, "All items should be removed")
    }

    // MARK: - Update Text Tests

    func testUpdateText() {
        viewModel.newTodoText = "Original"
        viewModel.addTodo()
        let item = viewModel.items[0]

        viewModel.updateText(item, newText: "Updated")

        XCTAssertEqual(viewModel.items[0].text, "Updated")
    }

    func testUpdateTextTrimsWhitespace() {
        viewModel.newTodoText = "Original"
        viewModel.addTodo()
        let item = viewModel.items[0]

        viewModel.updateText(item, newText: "  Trimmed  ")

        XCTAssertEqual(viewModel.items[0].text, "Trimmed")
    }

    func testUpdateTextWithEmptyRemovesItem() {
        viewModel.newTodoText = "Original"
        viewModel.addTodo()
        let item = viewModel.items[0]

        viewModel.updateText(item, newText: "")

        XCTAssertTrue(viewModel.items.isEmpty, "Empty text should remove item")
    }

    func testUpdateTextWithWhitespaceOnlyRemovesItem() {
        viewModel.newTodoText = "Original"
        viewModel.addTodo()
        let item = viewModel.items[0]

        viewModel.updateText(item, newText: "   ")

        XCTAssertTrue(viewModel.items.isEmpty, "Whitespace-only text should remove item")
    }

    // MARK: - Filter Tests

    func testFilterAll() {
        viewModel.newTodoText = "Active"
        viewModel.addTodo()
        viewModel.newTodoText = "Completed"
        viewModel.addTodo()
        viewModel.toggle(viewModel.items[1])

        viewModel.filter = .all

        XCTAssertEqual(viewModel.filteredItems.count, 2, "All filter should show all items")
    }

    func testFilterActive() {
        viewModel.newTodoText = "Active"
        viewModel.addTodo()
        viewModel.newTodoText = "Completed"
        viewModel.addTodo()
        viewModel.toggle(viewModel.items[1])

        viewModel.filter = .active

        XCTAssertEqual(viewModel.filteredItems.count, 1, "Active filter should show 1 item")
        XCTAssertEqual(viewModel.filteredItems[0].text, "Active")
    }

    func testFilterCompleted() {
        viewModel.newTodoText = "Active"
        viewModel.addTodo()
        viewModel.newTodoText = "Completed"
        viewModel.addTodo()
        viewModel.toggle(viewModel.items[1])

        viewModel.filter = .completed

        XCTAssertEqual(viewModel.filteredItems.count, 1, "Completed filter should show 1 item")
        XCTAssertEqual(viewModel.filteredItems[0].text, "Completed")
    }

    // MARK: - Computed Properties Tests

    func testActiveCount() {
        viewModel.newTodoText = "Active1"
        viewModel.addTodo()
        viewModel.newTodoText = "Active2"
        viewModel.addTodo()
        viewModel.newTodoText = "Completed"
        viewModel.addTodo()
        viewModel.toggle(viewModel.items[2])

        XCTAssertEqual(viewModel.activeCount, 2, "Active count should be 2")
    }

    func testCompletedCount() {
        viewModel.newTodoText = "Active"
        viewModel.addTodo()
        viewModel.newTodoText = "Completed1"
        viewModel.addTodo()
        viewModel.newTodoText = "Completed2"
        viewModel.addTodo()
        viewModel.toggle(viewModel.items[1])
        viewModel.toggle(viewModel.items[2])

        XCTAssertEqual(viewModel.completedCount, 2, "Completed count should be 2")
    }

    func testItemsLeftTextSingular() {
        viewModel.newTodoText = "One item"
        viewModel.addTodo()

        XCTAssertEqual(viewModel.itemsLeftText, "1 item left", "Should use singular form")
    }

    func testItemsLeftTextPlural() {
        viewModel.newTodoText = "First"
        viewModel.addTodo()
        viewModel.newTodoText = "Second"
        viewModel.addTodo()

        XCTAssertEqual(viewModel.itemsLeftText, "2 items left", "Should use plural form")
    }

    func testAllCompletedWithEmptyList() {
        XCTAssertFalse(viewModel.allCompleted, "allCompleted should be false when empty")
    }

    func testAllCompletedWithAllCompleted() {
        viewModel.newTodoText = "First"
        viewModel.addTodo()
        viewModel.newTodoText = "Second"
        viewModel.addTodo()
        viewModel.toggleAll()

        XCTAssertTrue(viewModel.allCompleted, "allCompleted should be true when all completed")
    }

    func testAllCompletedWithMixedState() {
        viewModel.newTodoText = "First"
        viewModel.addTodo()
        viewModel.newTodoText = "Second"
        viewModel.addTodo()
        viewModel.toggle(viewModel.items[0])

        XCTAssertFalse(viewModel.allCompleted, "allCompleted should be false with mixed state")
    }

    // MARK: - TodoItem Tests

    func testTodoItemEquality() {
        let item1 = TodoItem(text: "Test")
        let item2 = TodoItem(text: "Test")

        XCTAssertNotEqual(item1, item2, "Different instances should not be equal (different UUIDs)")
        XCTAssertEqual(item1, item1, "Same instance should be equal")
    }

    func testTodoItemInitialization() {
        let item = TodoItem(text: "Test", isCompleted: true)

        XCTAssertEqual(item.text, "Test")
        XCTAssertTrue(item.isCompleted)
    }

    func testTodoItemDefaultCompletion() {
        let item = TodoItem(text: "Test")

        XCTAssertFalse(item.isCompleted, "Default isCompleted should be false")
    }

    // MARK: - FilterMode Tests

    func testFilterModeRawValues() {
        XCTAssertEqual(FilterMode.all.rawValue, "All")
        XCTAssertEqual(FilterMode.active.rawValue, "Active")
        XCTAssertEqual(FilterMode.completed.rawValue, "Completed")
    }

    func testFilterModeAllCases() {
        XCTAssertEqual(FilterMode.allCases.count, 3)
        XCTAssertTrue(FilterMode.allCases.contains(.all))
        XCTAssertTrue(FilterMode.allCases.contains(.active))
        XCTAssertTrue(FilterMode.allCases.contains(.completed))
    }
}
