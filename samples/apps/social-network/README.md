# Social Network

Social networking application demonstrating feeds, profiles, posts, and interactions.

## Overview

Social Network showcases social app patterns:
- Feed timeline
- User profiles
- Posts and comments
- Likes and follows
- Notifications

## Project Structure

```
social-network/
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

### Feed
- Timeline posts
- Media attachments
- Like/comment actions
- Share functionality

### Profiles
- User information
- Post history
- Follower counts
- Following list

### Social
- Follow users
- Like posts
- Comment threads
- Direct messages

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
uint8_t app_get_screen(void);

// Posts
uint32_t app_create_post(const char* content, uint32_t len);
void app_like_post(uint32_t post_id);
void app_unlike_post(uint32_t post_id);

// Social
void app_follow_user(uint32_t user_id);
void app_unfollow_user(uint32_t user_id);
```

## Data Model

### Post
```zig
const Post = struct {
    id: u32,
    author_id: u32,
    content: []const u8,
    likes: u32,
    comments: u32,
    created_at: i64,
};
```

### User
```zig
const User = struct {
    id: u32,
    username: []const u8,
    display_name: []const u8,
    followers: u32,
    following: u32,
};
```

## License

MIT License
