package com.zylix.demo

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.outlined.CheckCircle
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.zylix.demo.ui.theme.ZylixDemoTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            ZylixDemoTheme {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colorScheme.background
                ) {
                    TodoApp()
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TodoApp(viewModel: TodoViewModel = viewModel()) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Column {
                        Text("Zylix Todo")
                        Text(
                            text = "ZigDom + Kotlin",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
                        )
                    }
                }
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
        ) {
            // Input field
            TodoInput(
                text = viewModel.newTodoText.value,
                onTextChange = { viewModel.newTodoText.value = it },
                onAddClick = { viewModel.addTodo() },
                onToggleAllClick = { viewModel.toggleAll() },
                allCompleted = viewModel.allCompleted,
                hasItems = viewModel.items.isNotEmpty()
            )

            // Filter tabs
            FilterTabs(
                currentFilter = viewModel.filter.value,
                onFilterChange = { viewModel.setFilter(it) }
            )

            // Todo list
            LazyColumn(
                modifier = Modifier.weight(1f)
            ) {
                items(viewModel.filteredItems, key = { it.id }) { item ->
                    TodoRow(
                        item = item,
                        onToggle = { viewModel.toggleTodo(item) },
                        onDelete = { viewModel.removeTodo(item) }
                    )
                }
            }

            // Footer
            TodoFooter(
                activeCount = viewModel.activeCount,
                completedCount = viewModel.completedCount,
                onClearCompleted = { viewModel.clearCompleted() }
            )

            // Stats
            StatsPanel(
                todoCount = viewModel.items.size,
                renderCount = viewModel.renderCount.value,
                renderTime = viewModel.lastRenderTime.value
            )
        }
    }
}

@Composable
fun TodoInput(
    text: String,
    onTextChange: (String) -> Unit,
    onAddClick: () -> Unit,
    onToggleAllClick: () -> Unit,
    allCompleted: Boolean,
    hasItems: Boolean
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        IconButton(
            onClick = onToggleAllClick,
            enabled = hasItems
        ) {
            Icon(
                imageVector = if (allCompleted) Icons.Filled.CheckCircle else Icons.Outlined.CheckCircle,
                contentDescription = "Toggle all",
                tint = if (allCompleted) MaterialTheme.colorScheme.primary else Color.Gray
            )
        }

        OutlinedTextField(
            value = text,
            onValueChange = onTextChange,
            modifier = Modifier.weight(1f),
            placeholder = { Text("What needs to be done?") },
            singleLine = true,
            keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
            keyboardActions = KeyboardActions(onDone = { onAddClick() })
        )

        IconButton(
            onClick = onAddClick,
            enabled = text.trim().isNotEmpty()
        ) {
            Icon(
                imageVector = Icons.Default.Add,
                contentDescription = "Add todo",
                tint = MaterialTheme.colorScheme.primary
            )
        }
    }
}

@Composable
fun FilterTabs(
    currentFilter: TodoFilter,
    onFilterChange: (TodoFilter) -> Unit
) {
    TabRow(
        selectedTabIndex = currentFilter.ordinal
    ) {
        TodoFilter.entries.forEach { filter ->
            Tab(
                selected = currentFilter == filter,
                onClick = { onFilterChange(filter) },
                text = { Text(filter.name.lowercase().replaceFirstChar { it.uppercase() }) }
            )
        }
    }
}

@Composable
fun TodoRow(
    item: TodoItem,
    onToggle: () -> Unit,
    onDelete: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onToggle() }
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            imageVector = if (item.isCompleted) Icons.Filled.CheckCircle else Icons.Outlined.CheckCircle,
            contentDescription = "Toggle",
            tint = if (item.isCompleted) MaterialTheme.colorScheme.primary else Color.Gray,
            modifier = Modifier.clickable { onToggle() }
        )

        Spacer(modifier = Modifier.width(16.dp))

        Text(
            text = item.text,
            modifier = Modifier.weight(1f),
            style = MaterialTheme.typography.bodyLarge.copy(
                textDecoration = if (item.isCompleted) TextDecoration.LineThrough else TextDecoration.None,
                color = if (item.isCompleted) Color.Gray else MaterialTheme.colorScheme.onSurface
            )
        )

        IconButton(onClick = onDelete) {
            Icon(
                imageVector = Icons.Default.Delete,
                contentDescription = "Delete",
                tint = MaterialTheme.colorScheme.error.copy(alpha = 0.7f)
            )
        }
    }
    Divider()
}

@Composable
fun TodoFooter(
    activeCount: Int,
    completedCount: Int,
    onClearCompleted: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = "$activeCount item${if (activeCount == 1) "" else "s"} left",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
        )

        if (completedCount > 0) {
            TextButton(onClick = onClearCompleted) {
                Text(
                    text = "Clear Completed",
                    color = MaterialTheme.colorScheme.error
                )
            }
        }
    }
}

@Composable
fun StatsPanel(
    todoCount: Int,
    renderCount: Int,
    renderTime: Double
) {
    Divider()
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(16.dp),
        horizontalArrangement = Arrangement.SpaceEvenly
    ) {
        StatItem(label = "Todos", value = todoCount.toString())
        StatItem(label = "Renders", value = renderCount.toString())
        StatItem(label = "Render Time", value = String.format("%.2f ms", renderTime))
    }
}

@Composable
fun StatItem(label: String, value: String) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(
            text = value,
            style = MaterialTheme.typography.titleMedium
        )
        Text(
            text = label,
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
        )
    }
}
