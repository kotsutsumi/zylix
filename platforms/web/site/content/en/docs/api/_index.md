---
title: "API Reference"
weight: 10
bookCollapseSection: true
---

# Zylix Core API Reference

This section provides detailed API documentation for the Zylix Core library.

## Overview

Zylix Core exposes its functionality through a C ABI interface, enabling integration with native platform shells (iOS/SwiftUI, Android/Compose, Web/WASM).

## Modules

### Core Modules

- [C ABI]({{< relref "abi" >}}) - Public C interface for platform integration
- [State Management]({{< relref "state" >}}) - Application state management
- [Events]({{< relref "events" >}}) - Event system and dispatching
- [Virtual DOM]({{< relref "vdom" >}}) - Virtual DOM reconciliation

### Additional Modules

- [Animation]({{< relref "animation" >}}) - Animation system with timeline, state machine, Lottie/Live2D support
- [AI]({{< relref "ai" >}}) - AI/ML backends (Whisper, VLM)

## Quick Reference

### Initialization

```c
// Initialize Zylix Core
int result = zylix_init();

// Get ABI version
uint32_t version = zylix_get_abi_version();

// Shutdown
zylix_deinit();
```

### Event Dispatch

```c
// Dispatch a counter increment event
zylix_dispatch(0x1000, NULL, 0);

// Queue an event with priority
zylix_queue_event(0x1000, NULL, 0, 1);  // priority: 1=normal

// Process queued events
uint32_t processed = zylix_process_events(10);
```

### State Access

```c
// Get current state
const ABIState* state = zylix_get_state();

// Get state version
uint64_t version = zylix_get_state_version();

// Check for changes
const ABIDiff* diff = zylix_get_diff();
bool changed = zylix_field_changed(0);  // field_id: 0=counter
```

## ABI Version

Current ABI version: **2**

The ABI version is bumped when breaking changes are made to the C interface. Platform shells should check the version at initialization:

```c
uint32_t version = zylix_get_abi_version();
if (version < 2) {
    // Handle older API
}
```
