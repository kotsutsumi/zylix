---
title: Linux Tutorial
weight: 5
---

## Overview

Run the GTK4 Todo/Counter demos on Linux.

## Prerequisites

- GTK 4.0+
- GCC or Clang
- pkg-config
- Make

## 1. Clone the Repo

```bash
git clone https://github.com/kotsutsumi/zylix.git
cd zylix
```

## 2. Build the GTK App

```bash
cd platforms/linux/zylix-gtk
make
```

## 3. Run

```bash
make run-counter
# or
make run-todo
```

## 4. Confirm State Updates

Use the counter buttons or add a Todo item and verify the UI updates.

Key files:

- `platforms/linux/zylix-gtk/main.c` (Counter UI)
- `platforms/linux/zylix-gtk/todo_app.c` (Todo UI)

## Troubleshooting

- Build fails: verify GTK4 dev packages and `pkg-config` are installed.
- App does not start: run `./build/zylix-counter` directly to see errors.

## Next Steps

- [State Management](/docs/core-concepts/state-management/)
- [Events](/docs/core-concepts/events/)
- [Platform Guide](/docs/platforms/linux/)
