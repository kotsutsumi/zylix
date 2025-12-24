---
title: APIリファレンス
weight: 50
---

# Zylix APIリファレンス

Zylixの全モジュールに関する完全なAPIドキュメントです。クロスプラットフォームアプリケーションを構築するための公開APIをカバーしています。

## モジュール概要

### コアモジュール

| モジュール | 説明 |
|-----------|------|
| **State** | 差分追跡付きアプリケーション状態管理 |
| **Events** | ユーザーインタラクション用イベントシステム |
| **VDOM** | 仮想DOM実装 |
| **Component** | ライフサイクル付きコンポーネントシステム |
| **Router** | クライアントサイドルーティング |
| **ABI** | プラットフォーム統合用C ABI |

### 機能モジュール

| モジュール | 説明 |
|-----------|------|
| **AI** | AI/ML統合 (LLM, Whisper) |
| **Animation** | タイムライン、ステートマシン、Lottie、Live2D |
| **Graphics3D** | シーングラフ付き3Dレンダリング |
| **Server** | HTTP/gRPCサーバーランタイム |
| **Edge** | エッジプラットフォームアダプター (Cloudflare, Vercel, AWS) |
| **Database** | データベース接続 |

### 生産性モジュール

| モジュール | 説明 |
|-----------|------|
| **PDF** | PDF生成・解析 |
| **Excel** | Excelファイル処理 |
| **NodeFlow** | ノードベースUIシステム |

### パフォーマンスモジュール

| モジュール | 説明 |
|-----------|------|
| **Performance** | プロファイリング、メモリプール、レンダーバッチング |
| **Error Boundary** | エラー分離と復旧 |
| **Analytics** | クラッシュレポートと分析 |
| **Bundle** | バンドル分析とツリーシェイキング |

## クイックリファレンス

### 状態管理

```zig
const zylix = @import("zylix");

// 状態の初期化
zylix.state.init();
defer zylix.state.deinit();

// 状態へのアクセス
const current = zylix.state.getState();
std.debug.print("カウンター: {d}\n", .{current.app.counter});

// 状態の変更
zylix.state.handleIncrement();

// UI更新用の差分取得
const diff = zylix.state.calculateDiff();
```

### イベント処理

```zig
const events = zylix.events;

// イベントのディスパッチ
const result = events.dispatch(
    @intFromEnum(events.EventType.counter_increment),
    null,
    0
);

// ペイロード付き
const payload = events.ButtonEvent{ .button_id = 0 };
_ = events.dispatch(
    @intFromEnum(events.EventType.button_press),
    @ptrCast(&payload),
    @sizeOf(events.ButtonEvent)
);
```

### HTTPサーバー

```zig
const server = zylix.server;

var app = try server.Zylix.init(allocator, .{
    .port = 8080,
    .workers = 4,
});
defer app.deinit();

app.get("/", handleIndex);
app.get("/api/users", handleUsers);
app.post("/api/users", createUser);

try app.listen();
```

### パフォーマンスプロファイリング

```zig
const perf = zylix.perf;

var profiler = try perf.Profiler.init(allocator, .{
    .enable_diff_cache = true,
    .target_frame_time_ns = 16_666_667, // 60fps
});
defer profiler.deinit();

// セクションの計測
var section = profiler.beginSection("render");
renderFrame();
const duration = profiler.endSection(&section);

// メトリクスの確認
const metrics = profiler.getMetrics();
if (!metrics.isWithinTarget(16_666_667)) {
    std.debug.print("遅いフレーム: {d}ms\n", .{duration / 1_000_000});
}
```

### エラーバウンダリー

```zig
const error_boundary = zylix.perf.error_boundary;

var boundary = try error_boundary.ErrorBoundary.init(allocator, "App");
defer boundary.deinit();

_ = boundary
    .onError(handleError)
    .fallback(renderFallback)
    .withMaxRetries(3);

// エラーのキャッチ
boundary.catchError(
    error_boundary.ErrorContext.init("レンダー失敗", .@"error")
);

// リカバリー
if (boundary.tryRecover()) {
    // リトライ
} else {
    // フォールバックを使用
}
```

## 型リファレンス

### コア型

```zig
// 状態型
pub const State = zylix.State;
pub const AppState = zylix.AppState;
pub const UIState = zylix.UIState;

// イベント型
pub const EventType = zylix.EventType;

// サーバー型
pub const Zylix = zylix.Zylix;
pub const HttpRequest = zylix.HttpRequest;
pub const HttpResponse = zylix.HttpResponse;

// パフォーマンス型
pub const Profiler = zylix.Profiler;
pub const PerfConfig = zylix.PerfConfig;
pub const PerfMetrics = zylix.PerfMetrics;

// エッジ型
pub const EdgePlatform = zylix.EdgePlatform;
pub const CloudflareAdapter = zylix.CloudflareAdapter;
pub const VercelAdapter = zylix.VercelAdapter;
```

### 設定型

```zig
// パフォーマンス設定
pub const PerfConfig = struct {
    enable_diff_cache: bool = true,
    max_diff_cache_size: usize = 1000,
    enable_memory_pool: bool = true,
    pool_initial_size: usize = 1024 * 1024,
    enable_render_batching: bool = true,
    target_frame_time_ns: u64 = 16_666_667,
    enable_error_boundaries: bool = true,
    enable_analytics: bool = false,
    enable_crash_reporting: bool = false,
    optimization_level: OptimizationLevel = .balanced,
};
```

## ビルドコマンド

```bash
# ネイティブビルド
cd core && zig build

# テスト実行
cd core && zig build test

# クロスコンパイル
zig build -Dtarget=wasm32-freestanding    # WebAssembly
zig build -Dtarget=aarch64-macos          # macOS ARM64
zig build -Dtarget=aarch64-linux-android  # Android ARM64
zig build -Dtarget=x86_64-linux           # Linux x64
zig build -Dtarget=x86_64-windows         # Windows x64
```

## 完全なAPIドキュメント

すべての型、関数、サンプルを含む完全なAPIドキュメントは以下を参照:

- [GitHub: docs/API/](https://github.com/kotsutsumi/zylix/tree/main/docs/API)
- [コアモジュール](https://github.com/kotsutsumi/zylix/tree/main/docs/API/core)
- [パフォーマンスモジュール](https://github.com/kotsutsumi/zylix/tree/main/docs/API/perf)

## 関連リソース

- [はじめに](../getting-started) - クイックスタートガイド
- [コアコンセプト](../core-concepts) - Zylixアーキテクチャの理解
- [アーキテクチャ](../architecture) - 内部構造の詳細
