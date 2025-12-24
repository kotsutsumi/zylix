# Taskmaster

Advanced task management application with projects, priorities, and due dates.

## Overview

Taskmaster demonstrates a full-featured productivity application:
- Project organization
- Task priorities and due dates
- Tags and filtering
- Progress tracking
- Multiple views (list, board, calendar)

## Project Structure

```
taskmaster/
├── README.md
├── core/
│   ├── build.zig
│   └── src/
│       ├── main.zig    # Entry point
│       ├── app.zig     # App state
│       └── ui.zig      # UI components
└── platforms/
```

## Features

### Projects
- Create and organize projects
- Project colors and icons
- Archive completed projects
- Project progress tracking

### Tasks
- Create tasks with titles and descriptions
- Set priority levels (low, medium, high, urgent)
- Due dates and reminders
- Subtasks and checklists
- Tags for categorization

### Views
- List view with sorting
- Kanban board view
- Calendar view
- Today/upcoming filters

### Organization
- Drag and drop reordering
- Bulk actions
- Search and filter
- Sort by various fields

## Quick Start

```bash
cd core && zig build
zig build test
zig build wasm
```

## C ABI Exports

```c
// Initialization
void app_init(void);
void app_deinit(void);

// View management
void app_set_view(uint8_t view);
uint8_t app_get_view(void);

// Project operations
uint32_t app_create_project(void);
void app_select_project(uint32_t id);
void app_delete_project(uint32_t id);

// Task operations
uint32_t app_create_task(void);
void app_toggle_task(uint32_t id);
void app_set_task_priority(uint32_t id, uint8_t priority);
void app_delete_task(uint32_t id);

// Filtering
void app_set_filter(uint8_t filter);
void app_set_sort(uint8_t sort);
```

## Data Model

### Project
```zig
const Project = struct {
    id: u32,
    name: [64]u8,
    color: u32,
    task_count: u32,
    completed_count: u32,
    archived: bool,
};
```

### Task
```zig
const Task = struct {
    id: u32,
    project_id: u32,
    title: [128]u8,
    priority: Priority,
    due_date: i64,
    completed: bool,
    tags: [4]u8,
};
```

## Related Apps

- [Note Flow](../note-flow/) - Rich text notes
- [Fit Track](../fit-track/) - Fitness tracking

## License

MIT License
