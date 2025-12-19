---
title: "コンセプト"
weight: 1
---

# コンセプト

## 思想

> **「UIを共通化せず、意味と判断だけを共通化する」**

FlutterやReact Nativeがカスタムレンダリングで統一UIを描画するのに対し、Zylixは各プラットフォームのネイティブUIフレームワークを尊重します。そして本当に重要なものだけを中央集約します：**状態**、**ロジック**、**判断**。

## UI統一化の問題点

| アプローチ | トレードオフ |
|-----------|-------------|
| Flutter | Skiaによるカスタムレンダリング - ネイティブ感の喪失 |
| React Native | ブリッジオーバーヘッド - パフォーマンス問題 |
| Electron | Chromiumバンドル - 150MB以上のバイナリ |
| Tauri | WebView - 限定的なネイティブ統合 |

## Zylixのソリューション

Zylixは異なるアプローチを取ります：

1. **Zigコア**: すべての状態とロジックはZigに
2. **C ABI境界**: ネイティブコードへのゼロコストFFI
3. **ネイティブUIシェル**: SwiftUI、Composeなどが自然にレンダリング
4. **ランタイム不要**: 静的ライブラリ、VMやGCなし

## メリット

### ユーザーにとって
- ネイティブなルック&フィール
- ネイティブなアクセシビリティ（IME、VoiceOver、TalkBack）
- より小さいアプリサイズ
- より良いバッテリー持続時間

### 開発者にとって
- ロジックの単一ソース
- コンパイル時型安全性
- 単一ツールチェーンからのクロスコンパイル
- 予測可能なメモリ管理

## 何が共有されるか？

| 共有（Zig） | プラットフォーム固有 |
|------------|---------------------|
| アプリケーション状態 | UIコンポーネント |
| ビジネスロジック | アニメーション |
| データバリデーション | プラットフォームAPI |
| イベント処理 | アクセシビリティ |
| 永続化ロジック | ネイティブジェスチャー |

## 例：カウンターアプリ

**Zigコア（共有）**:
```zig
pub const State = struct {
    counter: i64 = 0,
};

pub fn increment(state: *State) void {
    state.counter += 1;
}
```

**SwiftUI（iOS/macOS）**:
```swift
Text("\(zylixState.counter)")
Button("増加") {
    zylix_dispatch(.increment)
}
```

**Jetpack Compose（Android）**:
```kotlin
Text("${zylixState.counter}")
Button(onClick = { zylixDispatch(INCREMENT) }) {
    Text("増加")
}
```

同じロジック、ネイティブUI、妥協なし。
