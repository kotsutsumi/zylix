# Media Box

Media player application demonstrating audio/video playback, playlists, and media controls.

## Overview

Media Box showcases media player patterns:
- Audio/video playback
- Playlist management
- Playback controls
- Media library
- Now playing screen

## Project Structure

```
media-box/
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

### Playback
- Play/pause/stop
- Seek and scrub
- Volume control
- Shuffle/repeat

### Library
- Browse by artist
- Browse by album
- Browse by genre
- Search

### Playlists
- Create playlists
- Add/remove tracks
- Reorder tracks

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

// Playback
void app_play(void);
void app_pause(void);
void app_next_track(void);
void app_prev_track(void);
void app_seek(float position);
void app_set_volume(float volume);

// Library
void app_select_track(uint32_t id);
void app_select_album(uint32_t id);
```

## Data Model

### Track
```zig
const Track = struct {
    id: u32,
    title: [64]u8,
    artist: [32]u8,
    album: [32]u8,
    duration: u32,  // seconds
};
```

## License

MIT License
