---
title: Platforms
weight: 3
prev: architecture
sidebar:
  open: true
---

Zylix supports 6 platforms with native performance on each.

{{< cards >}}
  {{< card link="web" title="Web/WASM" subtitle="HTML, JavaScript, WebAssembly" >}}
  {{< card link="ios" title="iOS" subtitle="SwiftUI, UIKit" >}}
  {{< card link="android" title="Android" subtitle="Jetpack Compose, Kotlin" >}}
  {{< card link="macos" title="macOS" subtitle="SwiftUI, AppKit" >}}
  {{< card link="linux" title="Linux" subtitle="GTK4, C" >}}
  {{< card link="windows" title="Windows" subtitle="WinUI 3, C#" >}}
{{< /cards >}}

## Platform Comparison

| Feature | Web | iOS | Android | macOS | Linux | Windows |
|---------|-----|-----|---------|-------|-------|---------|
| Framework | HTML/JS | SwiftUI | Compose | SwiftUI | GTK4 | WinUI 3 |
| Language | JS | Swift | Kotlin | Swift | C | C# |
| Binding | WASM | C ABI | JNI | C ABI | C ABI | P/Invoke |
| Bundle Size | ~50KB | ~100KB | ~150KB | ~100KB | ~80KB | ~120KB |
| Hot Reload | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ |

## Binding Strategies

### WASM (Web)

Direct WebAssembly compilation with JavaScript glue code.

```javascript
const zylix = await WebAssembly.instantiate(wasmBuffer, imports);
zylix.exports.zylix_init();
```

### C ABI (iOS, macOS, Linux)

Static library linking with C function imports.

```swift
@_silgen_name("zylix_init")
func zylix_init() -> Int32
```

### JNI (Android)

Java Native Interface for Kotlin/Java interop.

```kotlin
external fun init(): Int
```

### P/Invoke (Windows)

.NET source-generated interop.

```csharp
[LibraryImport("zylix", EntryPoint = "zylix_init")]
public static partial int Init();
```
