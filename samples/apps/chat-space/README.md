# Chat Space

Real-time messaging application demonstrating chat, channels, and user presence.

## Overview

Chat Space showcases messaging application patterns:
- Channel-based messaging
- Direct messages
- User presence status
- Message history
- Typing indicators

## Project Structure

```
chat-space/
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

### Channels
- Public channels
- Private channels
- Channel creation
- Member management

### Messaging
- Text messages
- Message timestamps
- Message history
- Unread counts

### User Presence
- Online status
- Last seen
- Typing indicators

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

// Navigation
void app_set_screen(uint8_t screen);
void app_select_channel(uint32_t id);
void app_select_user(uint32_t id);

// Messaging
void app_send_message(const char* text, size_t len);
void app_set_typing(int32_t is_typing);

// Channels
void app_create_channel(const char* name, size_t len);
void app_join_channel(uint32_t id);
void app_leave_channel(uint32_t id);
```

## Data Model

### Message
```zig
const Message = struct {
    id: u32,
    channel_id: u32,
    sender_id: u32,
    text: [256]u8,
    timestamp: i64,
};
```

### Channel
```zig
const Channel = struct {
    id: u32,
    name: [32]u8,
    is_private: bool,
    unread_count: u32,
};
```

## License

MIT License
