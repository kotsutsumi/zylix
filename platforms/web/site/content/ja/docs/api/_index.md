---
title: "APIリファレンス"
weight: 10
bookCollapseSection: true
---

# Zylix Core APIリファレンス

このセクションでは、Zylix Coreライブラリの詳細なAPIドキュメントを提供します。

## 概要

Zylix Coreは、C ABIインターフェースを通じて機能を公開し、ネイティブプラットフォームシェル（iOS/SwiftUI、Android/Compose、Web/WASM）との統合を可能にします。

## モジュール

### コアモジュール

- [C ABI]({{< relref "abi" >}}) - プラットフォーム統合用の公開Cインターフェース
- [状態管理]({{< relref "state" >}}) - アプリケーション状態管理
- [イベント]({{< relref "events" >}}) - イベントシステムとディスパッチ
- [仮想DOM]({{< relref "vdom" >}}) - 仮想DOM差分検出

### 追加モジュール

- [アニメーション]({{< relref "animation" >}}) - タイムライン、ステートマシン、Lottie/Live2Dサポートを含むアニメーションシステム
- [AI]({{< relref "ai" >}}) - AI/MLバックエンド（Whisper、VLM）

## クイックリファレンス

### 初期化

```c
// Zylix Coreを初期化
int result = zylix_init();

// ABIバージョンを取得
uint32_t version = zylix_get_abi_version();

// シャットダウン
zylix_deinit();
```

### イベントディスパッチ

```c
// カウンターインクリメントイベントをディスパッチ
zylix_dispatch(0x1000, NULL, 0);

// 優先度付きでイベントをキューに追加
zylix_queue_event(0x1000, NULL, 0, 1);  // 優先度: 1=通常

// キューに入れたイベントを処理
uint32_t processed = zylix_process_events(10);
```

### 状態アクセス

```c
// 現在の状態を取得
const ABIState* state = zylix_get_state();

// 状態バージョンを取得
uint64_t version = zylix_get_state_version();

// 変更をチェック
const ABIDiff* diff = zylix_get_diff();
bool changed = zylix_field_changed(0);  // フィールドID: 0=counter
```

## ABIバージョン

現在のABIバージョン: **2**

ABIバージョンは、Cインターフェースに破壊的変更が加えられた場合に更新されます。プラットフォームシェルは初期化時にバージョンをチェックする必要があります：

```c
uint32_t version = zylix_get_abi_version();
if (version < 2) {
    // 古いAPIを処理
}
```
