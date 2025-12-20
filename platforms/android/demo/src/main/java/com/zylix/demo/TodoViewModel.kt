package com.zylix.demo

import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.lifecycle.ViewModel

/**
 * Represents a single todo item.
 */
data class TodoItem(
    val id: Int,
    var text: String,
    var isCompleted: Boolean = false
)

/**
 * Filter modes for the todo list.
 */
enum class TodoFilter {
    ALL, ACTIVE, COMPLETED
}

/**
 * ViewModel for the Todo app.
 * This is a pure Kotlin implementation for demo purposes.
 */
class TodoViewModel : ViewModel() {

    private var nextId = 1
    private val _items = mutableStateListOf<TodoItem>()
    val items: List<TodoItem> get() = _items

    val newTodoText = mutableStateOf("")
    val filter = mutableStateOf(TodoFilter.ALL)
    val renderCount = mutableStateOf(0)
    val lastRenderTime = mutableStateOf(0.0)

    val filteredItems: List<TodoItem>
        get() = when (filter.value) {
            TodoFilter.ALL -> _items.toList()
            TodoFilter.ACTIVE -> _items.filter { !it.isCompleted }
            TodoFilter.COMPLETED -> _items.filter { it.isCompleted }
        }

    val activeCount: Int
        get() = _items.count { !it.isCompleted }

    val completedCount: Int
        get() = _items.count { it.isCompleted }

    val allCompleted: Boolean
        get() = _items.isNotEmpty() && _items.all { it.isCompleted }

    init {
        // Add sample todos
        addTodo("Learn Zig")
        addTodo("Build VDOM")
        addTodo("Create Android bindings")
    }

    fun addTodo(text: String? = null) {
        val todoText = (text ?: newTodoText.value).trim()
        if (todoText.isEmpty()) return

        val startTime = System.nanoTime()

        _items.add(TodoItem(id = nextId++, text = todoText))

        if (text == null) {
            newTodoText.value = ""
        }

        trackRender(startTime)
    }

    fun removeTodo(item: TodoItem) {
        val startTime = System.nanoTime()
        _items.removeIf { it.id == item.id }
        trackRender(startTime)
    }

    fun toggleTodo(item: TodoItem) {
        val startTime = System.nanoTime()
        val index = _items.indexOfFirst { it.id == item.id }
        if (index >= 0) {
            _items[index] = _items[index].copy(isCompleted = !_items[index].isCompleted)
        }
        trackRender(startTime)
    }

    fun toggleAll() {
        val startTime = System.nanoTime()
        val shouldComplete = !allCompleted
        _items.indices.forEach { index ->
            _items[index] = _items[index].copy(isCompleted = shouldComplete)
        }
        trackRender(startTime)
    }

    fun clearCompleted() {
        val startTime = System.nanoTime()
        _items.removeIf { it.isCompleted }
        trackRender(startTime)
    }

    fun setFilter(newFilter: TodoFilter) {
        filter.value = newFilter
    }

    private fun trackRender(startTime: Long) {
        val endTime = System.nanoTime()
        lastRenderTime.value = (endTime - startTime) / 1_000_000.0 // Convert to ms
        renderCount.value++
    }
}
