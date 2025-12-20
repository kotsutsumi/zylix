---
title: プラットフォーム
weight: 3
prev: architecture
sidebar:
  open: true
---

Zylix は 6 つのプラットフォームでネイティブパフォーマンスをサポートしています。

{{< cards >}}
  {{< card link="web" title="Web/WASM" subtitle="HTML, JavaScript, WebAssembly" >}}
  {{< card link="ios" title="iOS" subtitle="SwiftUI, UIKit" >}}
  {{< card link="android" title="Android" subtitle="Jetpack Compose, Kotlin" >}}
  {{< card link="macos" title="macOS" subtitle="SwiftUI, AppKit" >}}
  {{< card link="linux" title="Linux" subtitle="GTK4, C" >}}
  {{< card link="windows" title="Windows" subtitle="WinUI 3, C#" >}}
{{< /cards >}}

## プラットフォーム比較

| 機能 | Web | iOS | Android | macOS | Linux | Windows |
|---------|-----|-----|---------|-------|-------|---------|
| フレームワーク | HTML/JS | SwiftUI | Compose | SwiftUI | GTK4 | WinUI 3 |
| 言語 | JS | Swift | Kotlin | Swift | C | C# |
| バインディング | WASM | C ABI | JNI | C ABI | C ABI | P/Invoke |
| バンドルサイズ | ~50KB | ~100KB | ~150KB | ~100KB | ~80KB | ~120KB |
| ホットリロード | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ |

## バインディング戦略

### WASM (Web)

JavaScript グルーコードを使用した直接 WebAssembly コンパイル。

```javascript
const zylix = await WebAssembly.instantiate(wasmBuffer, imports);
zylix.exports.zylix_init();
```

### C ABI (iOS, macOS, Linux)

C 関数インポートを使用した静的ライブラリリンク。

```swift
@_silgen_name("zylix_init")
func zylix_init() -> Int32
```

### JNI (Android)

Kotlin/Java 相互運用のための Java Native Interface。

```kotlin
external fun init(): Int
```

### P/Invoke (Windows)

.NET ソース生成相互運用。

```csharp
[LibraryImport("zylix", EntryPoint = "zylix_init")]
public static partial int Init();
```
