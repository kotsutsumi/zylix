---
title: Web/WASM Tutorial
weight: 1
---

## Overview

Build and run the Zylix counter app in your browser using WebAssembly.

## Prerequisites

- Zig 0.15+
- A modern browser

## 1. Clone the Repo

```bash
git clone https://github.com/kotsutsumi/zylix.git
cd zylix
```

## 2. Build the Web Sample

```bash
cd samples/counter-wasm
./build.sh
```

This builds `samples/counter-wasm/zylix.wasm` and uses `samples/counter-wasm/zylix.js` as the JS bridge.

## 3. Run the Sample

```bash
python3 -m http.server 8080
# Open http://localhost:8080
```

## 4. Confirm State Updates

Click the + and - buttons. The counter value updates through Zylix state and events.

Key files:

- `samples/counter-wasm/index.html` (UI shell)
- `samples/counter-wasm/zylix.js` (WASM bridge)

## Troubleshooting

- WASM fails to load: rerun `./build.sh` and confirm `zylix.wasm` exists.
- Blank page: use an HTTP server, not `file://`.

## Next Steps

- [State Management](/docs/core-concepts/state-management/)
- [Events](/docs/core-concepts/events/)
- [API Reference](/docs/api-reference/)
