# Database Workshop Showcase

Demonstration of Zylix database and persistence capabilities.

## Overview

This showcase demonstrates database operations and data persistence:
- CRUD operations (Create, Read, Update, Delete)
- Query building and filtering
- Transactions and batch operations
- Schema management
- Key-value storage
- Data import/export

## Project Structure

```
database-workshop/
├── README.md
├── core/
│   ├── build.zig
│   └── src/
│       ├── main.zig       # Entry point
│       ├── app.zig        # App state
│       └── workshop.zig   # Database workshop UI
└── platforms/
```

## Features

### CRUD Operations
- Create records with validation
- Read with pagination
- Update individual fields
- Delete with confirmation
- Bulk operations

### Query Builder
- Filter by field values
- Sort ascending/descending
- Limit and offset
- Full-text search
- Compound queries

### Transactions
- Begin/commit/rollback
- Atomic batch operations
- Nested transactions
- Error recovery

### Schema Management
- Table definitions
- Column types
- Indexes
- Migrations

### Key-Value Store
- Simple get/set
- TTL support
- Namespaces
- Atomic operations

### Import/Export
- JSON format
- CSV format
- Backup/restore
- Data validation

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

// Mode selection
void app_select_mode(uint32_t mode);

// CRUD operations
void app_create_record(void);
void app_read_record(uint32_t id);
void app_update_record(uint32_t id);
void app_delete_record(uint32_t id);
uint32_t app_get_record_count(void);

// Query operations
void app_set_filter(const char* field, const char* value);
void app_set_sort(const char* field, uint8_t ascending);
void app_execute_query(void);
void app_clear_query(void);

// Transaction operations
void app_begin_transaction(void);
void app_commit_transaction(void);
void app_rollback_transaction(void);
int32_t app_is_in_transaction(void);

// Key-value operations
void app_kv_set(const char* key, const char* value);
const char* app_kv_get(const char* key);
void app_kv_delete(const char* key);

// Import/Export
void app_export_json(void);
void app_export_csv(void);
void app_import_data(void);
```

## Data Model

### Sample Record Schema
```zig
const Record = struct {
    id: u32,
    name: [64]u8,
    email: [128]u8,
    age: u8,
    active: bool,
    created_at: i64,
    updated_at: i64,
};
```

### Key-Value Entry
```zig
const KVEntry = struct {
    key: [64]u8,
    value: [256]u8,
    expires_at: i64,  // 0 = no expiry
};
```

## Platform Integration

### iOS (Swift)
```swift
import SQLite3

// Initialize database
var db: OpaquePointer?
sqlite3_open(dbPath, &db)

// Execute query
sqlite3_exec(db, "SELECT * FROM records", callback, nil, nil)
```

### Android (Kotlin)
```kotlin
import android.database.sqlite.SQLiteDatabase

// Initialize database
val db = openOrCreateDatabase("app.db", MODE_PRIVATE, null)

// Execute query
val cursor = db.rawQuery("SELECT * FROM records", null)
```

### Web (IndexedDB)
```javascript
const request = indexedDB.open("AppDB", 1);
request.onsuccess = (event) => {
    const db = event.target.result;
    const tx = db.transaction("records", "readwrite");
    const store = tx.objectStore("records");
    store.add(record);
};
```

## Related Showcases

- [Device Lab](../device-lab/) - Platform features
- [Component Gallery](../component-gallery/) - UI components

## License

MIT License
