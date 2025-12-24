# Zylix Sample Applications

This directory contains sample applications demonstrating Zylix usage across platforms.

## Sample Categories

### Templates (Starter Projects)

Ready-to-use templates to kickstart your Zylix projects.

| Template | Description | Status |
|----------|-------------|--------|
| [**blank-app**](./templates/blank-app/) | Minimal starter template | ✅ Ready |
| [**tab-navigation**](./templates/tab-navigation/) | Multi-tab app structure | ✅ Ready |
| [**drawer-navigation**](./templates/drawer-navigation/) | Side drawer navigation | ✅ Ready |
| [**dashboard-layout**](./templates/dashboard-layout/) | Dashboard with widgets | ✅ Ready |

### Showcase (Feature Demonstrations)

Comprehensive examples showcasing Zylix capabilities.

| Showcase | Description | Status |
|----------|-------------|--------|
| [**component-gallery**](./showcase/component-gallery/) | All UI components showcase | ✅ Ready |
| [**animation-studio**](./showcase/animation-studio/) | Animation system demos | ✅ Ready |
| [**3d-viewer**](./showcase/3d-viewer/) | 3D graphics rendering | ✅ Ready |
| [**game-arcade**](./showcase/game-arcade/) | Game engine features | ✅ Ready |
| [**ai-playground**](./showcase/ai-playground/) | AI/ML integration demos | ✅ Ready |
| [**device-lab**](./showcase/device-lab/) | Platform-specific features | ✅ Ready |
| [**database-workshop**](./showcase/database-workshop/) | Database operations | ✅ Ready |

### Apps (Full Applications)

Complete applications demonstrating real-world patterns.

| App | Description | Status |
|-----|-------------|--------|
| [**taskmaster**](./apps/taskmaster/) | Advanced todo with projects | ✅ Ready |
| [**shop-demo**](./apps/shop-demo/) | E-commerce application | ✅ Ready |
| [**chat-space**](./apps/chat-space/) | Real-time messaging | ✅ Ready |
| [**analytics-pro**](./apps/analytics-pro/) | Dashboard and charts | ✅ Ready |
| [**media-box**](./apps/media-box/) | Media player app | ✅ Ready |
| [**note-flow**](./apps/note-flow/) | Rich text notes | ✅ Ready |
| [**fit-track**](./apps/fit-track/) | Fitness tracking | ✅ Ready |
| [**social-network**](./apps/social-network/) | Social media app | ✅ Ready |

### Platform-Specific

Samples showcasing platform-exclusive features.

| Sample | Platform | Description | Status |
|--------|----------|-------------|--------|
| [**ios-exclusive**](./platform-specific/ios-exclusive/) | iOS | Apple-specific features | ✅ Ready |
| [**android-exclusive**](./platform-specific/android-exclusive/) | Android | Android-specific features | ✅ Ready |
| [**web-pwa**](./platform-specific/web-pwa/) | Web | Progressive Web App | ✅ Ready |
| [**desktop-native**](./platform-specific/desktop-native/) | Desktop | Native desktop features | ✅ Ready |
| [**watchos-companion**](./platform-specific/watchos-companion/) | watchOS | Apple Watch companion | ✅ Ready |

### Games

Game development samples using Zylix.

| Game | Description | Status |
|------|-------------|--------|
| [**platformer-adventure**](./games/platformer-adventure/) | 2D platformer game | ✅ Ready |
| [**puzzle-world**](./games/puzzle-world/) | Puzzle game collection | ✅ Ready |
| [**space-shooter**](./games/space-shooter/) | Space shooter game | ✅ Ready |
| [**vtuber-demo**](./games/vtuber-demo/) | VTuber/Live2D demo | ✅ Ready |

### Fullstack

End-to-end fullstack applications.

| Project | Description | Status |
|---------|-------------|--------|
| [**social-network-stack**](./fullstack/social-network-stack/) | Complete social network | ✅ Ready |
| [**project-board**](./fullstack/project-board/) | Project management | ✅ Ready |
| [**api-server-demo**](./fullstack/api-server-demo/) | API server example | ✅ Ready |

---

## Legacy Samples (Working)

These samples demonstrate the current Zylix WASM implementation.

| Sample | Platform | Status | Description |
|--------|----------|--------|-------------|
| [**counter-wasm**](./counter-wasm/) | Web/WASM | ✅ Working | Minimal counter demo |
| [**todo-wasm**](./todo-wasm/) | Web/WASM | ✅ Working | Full TodoMVC implementation |
| [**component-showcase**](./component-showcase/) | Web/WASM | ✅ Working | v0.7.0 Component Library |

## Getting Started

### New Templates

```bash
# Blank App template
cd templates/blank-app/core
zig build
zig build test

# Component Gallery
cd showcase/component-gallery/core
zig build
zig build test
```

### Legacy WASM Samples

```bash
# Counter demo
cd counter-wasm
./build.sh
python3 -m http.server 8080
# Open http://localhost:8080

# TodoMVC demo
cd todo-wasm
./build.sh
python3 -m http.server 8081
# Open http://localhost:8081

# Component Showcase
cd component-showcase
python3 -m http.server 8082
# Open http://localhost:8082
```

## Prerequisites

- **Zig** 0.15.0 or later
- **Python 3** (for development server) or any HTTP server
- Modern web browser with WebAssembly support

## Architecture

### Template Structure

```
templates/blank-app/
├── README.md
├── core/
│   ├── build.zig
│   └── src/
│       ├── main.zig    # Entry point
│       ├── app.zig     # State and logic
│       └── ui.zig      # UI components
└── platforms/
    ├── ios/            # iOS shell
    ├── android/        # Android shell
    └── web/            # Web shell
```

### Cross-Platform Flow

```
User Input → Platform Shell → C ABI/WASM → Zig Core
                                              ↓
                                        State Update
                                              ↓
                                        VNode Tree
                                              ↓
             Platform Shell ← C ABI/WASM ← Diff Patch
                    ↓
               Native UI
```

## Testing

```bash
# Template tests
cd templates/blank-app/core
zig build test

# Showcase tests
cd showcase/component-gallery/core
zig build test

# Legacy WASM tests
cd counter-wasm && npm test
cd todo-wasm && npm test
```

## Contributing

When adding new samples:

1. Follow the directory structure (templates/, showcase/, apps/, etc.)
2. Include comprehensive README.md
3. Add Zig tests for core logic
4. Mark status accurately (✅ Ready, 🚧 Planned, ❌ Deprecated)
5. Keep samples focused on demonstrating specific features

## License

MIT - Part of the Zylix framework
