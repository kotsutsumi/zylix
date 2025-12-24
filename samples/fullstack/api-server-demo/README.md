# API Server Demo

REST API server patterns demonstrating backend architecture.

## Overview

This sample showcases API server patterns:
- RESTful endpoint design
- Request/response handling
- JSON serialization
- Error handling
- Middleware patterns

## Project Structure

```
api-server-demo/
├── README.md
├── core/
│   ├── build.zig
│   └── src/
│       ├── main.zig    # Entry point
│       ├── api.zig     # API handlers
│       └── models.zig  # Data models
└── platforms/
    └── server/         # Server shell
```

## Features

### Endpoints
- CRUD operations for resources
- Query parameters support
- Path parameters
- Request body parsing

### Middleware
- Authentication
- Rate limiting
- Logging
- CORS handling

### Error Handling
- HTTP status codes
- Error responses
- Validation errors

### Response Formats
- JSON responses
- Pagination
- Filtering

## Quick Start

```bash
cd core && zig build
zig build test
zig build wasm
```

## API Endpoints

```
GET    /api/users          # List users
GET    /api/users/:id      # Get user
POST   /api/users          # Create user
PUT    /api/users/:id      # Update user
DELETE /api/users/:id      # Delete user

GET    /api/posts          # List posts
GET    /api/posts/:id      # Get post
POST   /api/posts          # Create post
```

## C ABI Exports

```c
// Request handling
void api_handle_request(uint8_t method, const char* path, const char* body);
const char* api_get_response_body(void);
uint16_t api_get_response_status(void);

// Configuration
void api_set_rate_limit(uint32_t requests_per_minute);
void api_set_auth_token(const char* token);
```

## Architecture

```
Request → Middleware → Handler → Response
```

## License

MIT License
