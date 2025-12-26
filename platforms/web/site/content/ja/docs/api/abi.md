---
title: "C ABI"
weight: 1
---

# C ABIリファレンス

C ABIモジュール（`abi.zig`）は、プラットフォームシェルがZylix Coreと通信するための公開インターフェースを提供します。

## 定数

### ABI_VERSION

```c
#define ZYLIX_ABI_VERSION 2
```

現在のABIバージョン番号。破壊的変更時に更新されます。

## 結果コード

```c
typedef enum {
    ZYLIX_OK = 0,
    ZYLIX_ERR_INVALID_ARG = 1,
    ZYLIX_ERR_OUT_OF_MEMORY = 2,
    ZYLIX_ERR_INVALID_STATE = 3,
    ZYLIX_ERR_NOT_INITIALIZED = 4
} ZylixResult;
```

## ライフサイクル関数

### zylix_init

```c
int32_t zylix_init(void);
```

Zylix Coreを初期化します。他の関数を呼び出す前に呼び出す必要があります。

**戻り値:** 成功時は`0`、失敗時はエラーコード。

**例:**

```c
if (zylix_init() != 0) {
    fprintf(stderr, "初期化に失敗: %s\n", zylix_get_last_error());
    return 1;
}
```

### zylix_deinit

```c
int32_t zylix_deinit(void);
```

Zylix Coreをシャットダウンし、リソースを解放します。

**戻り値:** 成功時は`0`。

### zylix_get_abi_version

```c
uint32_t zylix_get_abi_version(void);
```

ABIバージョン番号を取得します。

**戻り値:** ABIバージョン（現在は`2`）。

## 状態アクセス

### zylix_get_state

```c
const ABIState* zylix_get_state(void);
```

現在の状態への読み取り専用ポインタを取得します。

**戻り値:** `ABIState`構造体へのポインタ、または初期化されていない場合は`NULL`。

**ABIState構造体:**

```c
typedef struct {
    uint64_t version;           // 状態バージョン（単調増加）
    uint32_t screen;            // 現在の画面ID
    bool loading;               // 読み込みインジケータ
    const char* error_message;  // 最後のエラーメッセージ（null終端）
    const void* view_data;      // アプリケーション固有のビューデータ
    size_t view_data_size;      // view_dataのサイズ
} ABIState;
```

### zylix_get_state_version

```c
uint64_t zylix_get_state_version(void);
```

現在の状態バージョンを取得します。

**戻り値:** 状態バージョン番号、または初期化されていない場合は`0`。

## イベントディスパッチ

### zylix_dispatch

```c
int32_t zylix_dispatch(
    uint32_t event_type,
    const void* payload,
    size_t payload_len
);
```

イベントを即座にディスパッチします。

**パラメータ:**

| 名前 | 型 | 説明 |
|------|------|-------------|
| `event_type` | `uint32_t` | イベントタイプ識別子（イベントを参照） |
| `payload` | `const void*` | イベントペイロードデータ（`NULL`可） |
| `payload_len` | `size_t` | ペイロード長（バイト単位） |

**戻り値:** 成功時は`0`、失敗時はエラーコード。

**例:**

```c
// カウンターインクリメントをディスパッチ
zylix_dispatch(0x1000, NULL, 0);

// ペイロード付きでボタンプレスをディスパッチ
ButtonEvent btn = { .button_id = 1 };
zylix_dispatch(0x0100, &btn, sizeof(btn));
```

## イベントキュー（フェーズ2）

### zylix_queue_event

```c
int32_t zylix_queue_event(
    uint32_t event_type,
    const void* payload,
    size_t payload_len,
    uint8_t priority
);
```

イベントを後で処理するためにキューに追加します。

**パラメータ:**

| 名前 | 型 | 説明 |
|------|------|-------------|
| `event_type` | `uint32_t` | イベントタイプ識別子 |
| `payload` | `const void*` | イベントペイロードデータ |
| `payload_len` | `size_t` | ペイロード長（最大256バイト） |
| `priority` | `uint8_t` | 優先度レベル（0-3） |

**優先度レベル:**

| 値 | 名前 | 説明 |
|-------|------|-------------|
| 0 | 低 | バックグラウンドイベント |
| 1 | 通常 | 標準UIイベント |
| 2 | 高 | 重要なイベント |
| 3 | 即時 | キューをバイパスし、即座に処理 |

**戻り値:** 成功時は`0`。

### zylix_process_events

```c
uint32_t zylix_process_events(uint32_t max_events);
```

キューに入れたイベントを処理します。

**パラメータ:**

| 名前 | 型 | 説明 |
|------|------|-------------|
| `max_events` | `uint32_t` | 処理するイベントの最大数 |

**戻り値:** 実際に処理されたイベント数。

### zylix_queue_depth

```c
uint32_t zylix_queue_depth(void);
```

キュー内のイベント数を取得します。

**戻り値:** キューに入れられたイベント数。

### zylix_queue_clear

```c
void zylix_queue_clear(void);
```

キューに入れられたすべてのイベントをクリアします。

## 差分関数（フェーズ2）

### zylix_get_diff

```c
const ABIDiff* zylix_get_diff(void);
```

最後の状態変更以降の差分を取得します。

**戻り値:** `ABIDiff`構造体へのポインタ、または初期化されていない場合は`NULL`。

**ABIDiff構造体:**

```c
typedef struct {
    uint64_t changed_mask;  // 変更されたフィールドのビットマスク
    uint16_t change_count;  // 変更されたフィールド数
    uint64_t version;       // 差分時の状態バージョン
} ABIDiff;
```

### zylix_field_changed

```c
bool zylix_field_changed(uint16_t field_id);
```

特定のフィールドが変更されたかどうかをチェックします。

**パラメータ:**

| 名前 | 型 | 説明 |
|------|------|-------------|
| `field_id` | `uint16_t` | フィールド識別子（0-63） |

**戻り値:** フィールドが変更された場合は`true`。

**AppStateのフィールドID:**

| ID | フィールド | 説明 |
|----|-------|-------------|
| 0 | `counter` | カウンター値 |
| 1 | `input_text` | 入力テキストバッファ |
| 2 | `input_len` | 入力テキスト長 |

## ハプティクスAPI

### zylix_haptics_pulse

```c
int32_t zylix_haptics_pulse(void);
```

中程度の強度でシンプルなハプティックパルスをトリガーします。

**戻り値:** 成功時は`0`。

### zylix_haptics_pulse_with_intensity

```c
int32_t zylix_haptics_pulse_with_intensity(uint8_t intensity);
```

プリセット強度でハプティックパルスをトリガーします。

**パラメータ:**

| 値 | 強度 |
|-------|-----------|
| 0 | ソフト |
| 1 | ライト |
| 2 | ミディアム |
| 3 | ストロング |
| 4 | ヘビー |

### zylix_haptics_tick

```c
int32_t zylix_haptics_tick(void);
```

UIインタラクション用のクイックティックパルス。

### zylix_haptics_success / warning / error

```c
int32_t zylix_haptics_success(void);
int32_t zylix_haptics_warning(void);
int32_t zylix_haptics_error(void);
```

通知フィードバックハプティクス。

### zylix_haptics_set_enabled

```c
void zylix_haptics_set_enabled(bool enabled);
```

ハプティクスをグローバルに有効または無効にします。

### zylix_haptics_is_available

```c
bool zylix_haptics_is_available(void);
```

このプラットフォームでハプティクスが利用可能かどうかをチェックします。

## エラー処理

### zylix_get_last_error

```c
const char* zylix_get_last_error(void);
```

最後のエラーメッセージを取得します。

**戻り値:** null終端のエラーメッセージ文字列。

## ユーティリティ関数

### zylix_copy_string

```c
size_t zylix_copy_string(
    const char* src,
    size_t src_len,
    char* dst,
    size_t dst_len
);
```

Zylixメモリからシェルバッファに文字列を安全にコピーします。

**パラメータ:**

| 名前 | 型 | 説明 |
|------|------|-------------|
| `src` | `const char*` | ソース文字列ポインタ |
| `src_len` | `size_t` | ソース文字列長 |
| `dst` | `char*` | 出力先バッファ |
| `dst_len` | `size_t` | 出力先バッファサイズ |

**戻り値:** コピーされたバイト数（null終端を除く）。

`dst_len > 0`の場合、出力先は常にnull終端されます。
