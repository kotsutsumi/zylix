# Social Network Stack

Complete fullstack social network demonstrating end-to-end architecture.

## Overview

This sample showcases fullstack patterns:
- User authentication and profiles
- Real-time feed updates
- Post creation with media
- Social interactions (likes, comments, follows)
- Notifications system

## Project Structure

```
social-network-stack/
├── README.md
├── core/
│   ├── build.zig
│   └── src/
│       ├── main.zig    # Entry point
│       ├── app.zig     # Application state
│       └── ui.zig      # UI components
└── platforms/
    └── web/            # Web shell
```

## Features

### Authentication
- User registration
- Login/logout
- Session management
- Profile settings

### Feed
- Timeline posts
- Real-time updates
- Infinite scroll
- Content filtering

### Social
- Follow/unfollow
- Likes and comments
- Share/repost
- Direct messages

### Notifications
- Activity feed
- Push notifications
- Read/unread state
- Notification settings

## Quick Start

```bash
cd core && zig build
zig build test
zig build wasm
```

## C ABI Exports

```c
// Auth
void auth_login(const char* email, const char* password);
void auth_logout(void);
bool auth_is_logged_in(void);

// Posts
void post_create(const char* content);
void post_like(uint32_t post_id);
void post_comment(uint32_t post_id, const char* text);

// Social
void user_follow(uint32_t user_id);
void user_unfollow(uint32_t user_id);

// Feed
void feed_refresh(void);
void feed_load_more(void);
```

## Architecture

```
Client (Zig/WASM) <-> API Layer <-> Business Logic <-> Data Layer
```

## License

MIT License
