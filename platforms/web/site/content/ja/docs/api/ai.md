---
title: "AIモジュール"
weight: 6
---

# AIモジュール

AIモジュールは、Whisper（音声からテキスト）およびビジョン言語モデル（VLM）を含むローカルAI/MLバックエンドとの統合を提供します。

## 概要

```
┌─────────────────────────────────────────────┐
│                 AIモジュール                  │
│  ┌───────────────────────────────────────┐  │
│  │          モデルマネージャー            │  │
│  └───────────────────────────────────────┘  │
│  ┌───────────────┐  ┌───────────────────┐   │
│  │    Whisper    │  │       VLM         │   │
│  │  (音声から    │  │  (ビジョン言語    │   │
│  │    テキスト)  │  │     モデル)       │   │
│  └───────────────┘  └───────────────────┘   │
│              │                │              │
│              ▼                ▼              │
│  ┌───────────────────────────────────────┐  │
│  │     llama.cpp / whisper.cpp           │  │
│  │        （ネイティブバックエンド）       │  │
│  └───────────────────────────────────────┘  │
└─────────────────────────────────────────────┘
```

## モデルタイプ

```zig
pub const ModelType = enum {
    /// テキスト生成（LLaMA、Mistralなど）
    text,

    /// 音声からテキスト（Whisper）
    whisper,

    /// ビジョン言語（LLaVAなど）
    vision,

    /// テキストから音声
    tts,

    /// 埋め込みモデル
    embedding,
};

pub const ModelFormat = enum {
    gguf,      // GGUF形式（推奨）
    ggml,      // レガシーGGML形式
    safetensors,
    pytorch,
};
```

## Whisperバックエンド

Whisperモデルを使用した音声からテキストへの変換。

### 設定

```zig
pub const WhisperConfig = struct {
    /// Whisperモデルファイルへのパス（.bin）
    model_path: []const u8 = "",

    /// ターゲット言語（空 = 自動検出）
    language: []const u8 = "",

    /// 英語に翻訳
    translate: bool = false,

    /// CPUスレッド数
    n_threads: u8 = 4,

    /// GPUアクセラレーションを使用
    use_gpu: bool = true,

    /// 変換中に進行状況を表示
    print_progress: bool = false,

    /// セグメントごとの最大トークン数
    max_tokens_per_segment: u32 = 0,
};
```

### 使用方法

```zig
const ai = @import("ai/ai.zig");

// Whisperが利用可能かチェック
if (!ai.whisper.isWhisperAvailable()) {
    std.debug.print("Whisperはこのプラットフォームで利用できません\n", .{});
    return;
}

// バックエンドを初期化
var config = ai.whisper.WhisperConfig{
    .model_path = "models/whisper-base.bin",
    .language = "en",
    .n_threads = 4,
};

var backend = try ai.whisper.WhisperBackend.init(allocator, config);
defer backend.deinit();

// ステータスをチェック
if (backend.getStatus() != .ready) {
    return error.BackendNotReady;
}

// 音声を変換
const audio_samples: []const f32 = ...;  // 16kHzモノラル音声
const result = try backend.transcribe(audio_samples);
defer allocator.free(result.text);

std.debug.print("変換結果: {s}\n", .{result.text});
std.debug.print("言語: {s}\n", .{result.language});
```

### ステータス

```zig
pub const WhisperStatus = enum(u8) {
    uninitialized = 0,
    loading = 1,
    ready = 2,
    transcribing = 3,
    @"error" = 4,
    shutdown = 5,
};
```

### 変換結果

```zig
pub const TranscriptResult = struct {
    /// 変換されたテキスト
    text: []u8,
    text_len: usize,

    /// 検出された言語コード
    language: [8]u8,

    /// セグメント数
    n_segments: usize,
};
```

### 音声要件

- **サンプルレート**: 16,000 Hz（`ai.whisper.getSampleRate()`を使用）
- **チャンネル**: モノラル
- **形式**: 32ビット浮動小数点PCM

## VLMバックエンド

画像理解のためのビジョン言語モデル。

### 設定

```zig
pub const VLMConfig = struct {
    /// 言語モデルへのパス
    model_path: []const u8 = "",

    /// マルチモーダルプロジェクターへのパス
    mmproj_path: []const u8 = "",

    /// CPUスレッド数
    n_threads: u32 = 4,

    /// GPUアクセラレーションを使用
    use_gpu: bool = true,

    /// コンテキストサイズ
    n_ctx: u32 = 2048,

    /// 最大出力トークン数
    max_tokens: u32 = 512,

    /// サンプリング温度
    temperature: f32 = 0.1,

    /// Top-pサンプリング
    top_p: f32 = 0.9,
};
```

### 使用方法

```zig
const ai = @import("ai/ai.zig");

// VLMが利用可能かチェック
if (!ai.vlm.isVLMAvailable()) {
    std.debug.print("VLMはこのプラットフォームで利用できません\n", .{});
    return;
}

// バックエンドを初期化
var config = ai.vlm.VLMConfig{
    .model_path = "models/llava-1.5-7b.gguf",
    .mmproj_path = "models/llava-1.5-mmproj.gguf",
    .n_threads = 4,
    .max_tokens = 256,
};

var backend = try ai.vlm.VLMBackend.init(allocator, config);
defer backend.deinit();

// 画像を分析
const image_data: []const u8 = ...;  // 画像バイト（JPEG、PNG）
const prompt = "この画像を詳しく説明してください。";
const result = try backend.analyze(image_data, prompt);

std.debug.print("分析結果: {s}\n", .{result.text[0..result.text_len]});
std.debug.print("トークン: {d} 入力, {d} 出力\n", .{
    result.n_input_tokens,
    result.n_output_tokens,
});
```

### ステータス

```zig
pub const VLMStatus = enum {
    uninitialized,
    ready,
    processing,
    error_state,
};
```

### 分析結果

```zig
pub const AnalysisResult = struct {
    /// 生成されたテキスト
    text_len: usize,

    /// トークン数
    n_input_tokens: usize,
    n_output_tokens: usize,

    /// 処理時間（ミリ秒）
    processing_time_ms: u64,

    /// 検出された言語
    language: [8]u8,
};
```

### 機能

```zig
// モデルの機能をチェック
if (backend.supportsVision()) {
    // 画像を処理可能
}

if (backend.supportsAudio()) {
    // 音声を処理可能（将来）
}
```

## プラットフォーム対応

AIバックエンドはプラットフォームによって利用可能性が異なります：

| プラットフォーム | Whisper | VLM | 備考 |
|----------|---------|-----|-------|
| macOS（Apple Silicon） | はい | はい | Metal経由でフルGPUアクセラレーション |
| macOS（Intel） | はい | はい | CPUのみ |
| iOS | はい | 制限あり | デバイス上、メモリ制約あり |
| Android | はい | 制限あり | NNAPIアクセラレーション |
| Linux（CUDA） | はい | はい | フルGPUアクセラレーション |
| Linux（CPU） | はい | はい | AVX/AVX2最適化 |
| Windows | はい | はい | CUDAまたはCPU |
| Web（WASM） | いいえ | いいえ | スタブのみ（サーバーサイドを使用） |

## スタブモジュール

ネイティブCサポートのないプラットフォーム（例：WASM）では、スタブモジュールが提供されます：

```zig
// whisper_backend_stub.zig
pub fn isWhisperAvailable() bool {
    return false;  // サポートされていないプラットフォームでは常にfalse
}

// vlm_backend_stub.zig
pub fn isVLMAvailable() bool {
    return false;  // サポートされていないプラットフォームでは常にfalse
}
```

プラットフォームシェルはAI機能を使用する前に利用可能性をチェックする必要があります：

```swift
// iOS例
if zylix_ai_whisper_available() {
    // 変換UIを表示
} else {
    // 機能を非表示または無効化
}
```

## モデル管理

### モデルのダウンロード

```zig
const ai = @import("ai/ai.zig");

// Hugging Faceからダウンロード
try ai.models.download(.{
    .repo = "ggerganov/whisper.cpp",
    .file = "ggml-base.bin",
    .destination = "models/whisper-base.bin",
    .progress_callback = progressHandler,
});

// チェックサムを検証
const valid = try ai.models.verify(
    "models/whisper-base.bin",
    "sha256:abc123...",
);
```

### モデル情報

```zig
const info = try ai.models.getInfo("models/llava.gguf");
std.debug.print("モデル: {s}\n", .{info.name});
std.debug.print("パラメータ: {d}B\n", .{info.n_params / 1_000_000_000});
std.debug.print("量子化: {s}\n", .{@tagName(info.quantization)});
std.debug.print("コンテキストサイズ: {d}\n", .{info.n_ctx});
```

## パフォーマンスのヒント

1. **モデル選択**: モバイルでは量子化モデル（Q4_K_M、Q5_K_M）を使用
2. **バッチ処理**: 可能な場合は複数のリクエストをまとめて処理
3. **キャッシング**: リクエスト間でモデルインスタンスをキャッシュ
4. **メモリ管理**: 未使用のモデルをアンロードしてメモリを解放
5. **スレッディング**: デバイスの能力に応じて`n_threads`を調整
