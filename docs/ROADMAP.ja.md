# Zylix ロードマップ

> **最終更新**: 2025-12-24
> **現在のバージョン**: v0.19.0

---

## 概要

本ドキュメントは、Zylixフレームワーク開発ロードマップを記載しています。各フェーズは特定のバージョンマイルストーンに対応し、明確な成果物と成功基準を定義しています。

### ロードマップ概要

| バージョン | フェーズ | 主要機能 | ステータス | リリース日 |
|-----------|---------|---------|----------|----------|
| v0.1.0 | Phase 1-5 | 基盤構築 & 6プラットフォーム対応 | ✅ 完了 | 2025-12-21 |
| v0.5.0 | - | GitHub設定 & ドキュメント | ✅ 完了 | 2025-12-21 |
| v0.6.0 | Phase 7-10 | Router, Async, Hot Reload, サンプル | ✅ 完了 | 2025-12-21 |
| v0.6.1 | - | サンプルアプリのセキュリティ修正 | ✅ 完了 | 2025-12-21 |
| v0.6.2 | - | プラットフォームセキュリティ & 並行処理修正 | ✅ 完了 | 2025-12-21 |
| v0.6.3 | - | プラットフォームデモ (iOS, Android) | ✅ 完了 | 2025-12-22 |
| v0.7.0 | Phase 6 | コンポーネントライブラリの拡充 | ✅ 完了 | 2025-12-22 |
| v0.8.1 | Phase 11a | watchOS対応, 言語バインディング, CI/CD, E2Eテスト | ✅ 完了 | 2025-12-23 |
| v0.9.0 | Phase 11b | 組み込みAI (Zylix AI) | ✅ 完了 | 2025-12-24 |
| v0.10.0 | Phase 12 | デバイス機能 & ジェスチャー | ✅ 完了 | 2025-12-24 |
| v0.11.0 | Phase 13 | アニメーション (Lottie, Live2D) | ✅ 完了 | 2025-12-24 |
| v0.12.0 | Phase 14 | 3Dグラフィックス (Three.js風) | ✅ 完了 | 2025-12-24 |
| v0.13.0 | Phase 15 | ゲーム開発 (PIXI.js風, 物理エンジン, オーディオ) | ✅ 完了 | 2025-12-24 |
| v0.14.0 | Phase 16 | データベース (SQLite, MySQL, PostgreSQL, Turso/libSQL) | ✅ 完了 | 2025-12-24 |
| v0.15.0 | Phase 17 | アプリ統合API (IAP, 広告, KeyValueStore, ライフサイクル) | ✅ 完了 | 2025-12-24 |
| v0.16.0 | Phase 18 | 開発者ツール (Console, DevTools, Profiler) | ✅ 完了 | 2025-12-24 |
| v0.17.0 | Phase 19 | ノードベースUI (React Flow風 NodeFlow) | ✅ 完了 | 2025-12-24 |
| v0.18.0 | Phase 20 | PDFサポート (生成・読み込み・編集) + ベンチマーク | ✅ 完了 | 2025-12-24 |
| v0.19.0 | Phase 21 | Excelサポート (xlsx読み書き) | ✅ 完了 | 2025-12-24 |
| v0.20.0 | Phase 22 | mBaaS (Firebase, Supabase, AWS Amplify) | ⏳ 計画中 | 2025年Q4 |
| v0.21.0 | Phase 23 | サーバーランタイム (Zylix Server) | ⏳ 計画中 | 2026年Q1 |
| v0.22.0 | Phase 24 | エッジアダプター (Cloudflare, Vercel, AWS, Azure, Deno, GCP, Fastly) | ⏳ 計画中 | 2026年Q1 |
| v0.23.0 | Phase 25 | パフォーマンス & 最適化 | ⏳ 計画中 | 2026年Q2 |
| v0.24.0 | Phase 26 | ドキュメント充実 | ⏳ 計画中 | 2026年Q2 |
| v0.25.0 | Phase 27 | 公式サンプルプロジェクト (23種類以上) | ⏳ 計画中 | 2026年Q3 |

---

## Phase 6: コンポーネントライブラリの拡充 (v0.7.0) ✅ 完了

### 概要

現在の9種類の基本コンポーネントを、全プラットフォームで一般的なユースケースをカバーする包括的なUIコンポーネントライブラリに拡張します。

### 現在の状態 (v0.7.0)

```
コンポーネント（40種類以上）:
├── 基本コンポーネント（10種類）
│   ├── container   - div的なコンテナ
│   ├── text        - テキスト/span要素
│   ├── button      - クリック可能なボタン
│   ├── input       - テキスト入力フィールド
│   ├── image       - 画像要素
│   ├── link        - アンカーリンク
│   ├── list        - ul/olリスト
│   ├── list_item   - li項目
│   ├── heading     - h1-h6
│   └── paragraph   - p要素
│
├── フォームコンポーネント（7種類） ✅ 実装済み
│   ├── select        - ドロップダウン
│   ├── checkbox      - チェックボックス
│   ├── radio         - ラジオボタン
│   ├── textarea      - 複数行テキスト
│   ├── toggle_switch - トグルスイッチ
│   ├── slider        - スライダー
│   └── form          - フォームコンテナ
│
├── レイアウトコンポーネント（8種類） ✅ 実装済み
│   ├── vstack      - 縦スタック
│   ├── hstack      - 横スタック
│   ├── zstack      - 重ねスタック
│   ├── grid        - グリッドレイアウト
│   ├── scroll_view - スクロールビュー
│   ├── spacer      - スペーサー
│   ├── divider     - 区切り線
│   └── card        - カードコンテナ
│
├── ナビゲーションコンポーネント（2種類） ✅ 実装済み
│   ├── nav_bar  - ナビゲーションバー
│   └── tab_bar  - タブバー
│
├── フィードバックコンポーネント（5種類） ✅ 実装済み
│   ├── alert    - アラート
│   ├── toast    - トースト通知
│   ├── modal    - モーダル
│   ├── progress - プログレス
│   └── spinner  - スピナー
│
└── データ表示コンポーネント（5種類） ✅ 実装済み
    ├── icon      - アイコン
    ├── avatar    - アバター
    ├── tag       - タグ
    ├── badge     - バッジ
    └── accordion - アコーディオン
```

### 実装完了

- ✅ Zigコアでのコンポーネント定義 (`core/src/component.zig`)
- ✅ WASM exports (`core/src/wasm.zig`)
- ✅ JavaScript bindings (`packages/zylix/src/component.js`)
- ✅ component-showcase サンプルアプリ (`samples/component-showcase/`)
- ✅ Playwright E2Eテスト

### 追加予定コンポーネント

#### 6.1 フォームコンポーネント

| コンポーネント | 説明 | 優先度 | プラットフォーム備考 |
|--------------|------|-------|-------------------|
| `select` | ドロップダウン/ピッカー | P0 | モバイルではネイティブピッカー |
| `checkbox` | ブール値トグル | P0 | ネイティブスタイル |
| `radio` | グループから単一選択 | P0 | ネイティブスタイル |
| `textarea` | 複数行テキスト入力 | P0 | - |
| `switch` | トグルスイッチ | P1 | 全プラットフォームでiOS風 |
| `slider` | レンジ入力 | P1 | ネイティブレンジコントロール |
| `date_picker` | 日付選択 | P1 | ネイティブ日付ピッカー |
| `time_picker` | 時刻選択 | P1 | ネイティブ時刻ピッカー |
| `file_input` | ファイル選択 | P2 | プラットフォームファイルダイアログ |
| `color_picker` | 色選択 | P2 | - |
| `form` | バリデーション付きフォームコンテナ | P0 | - |

#### 6.2 レイアウトコンポーネント

| コンポーネント | 説明 | 優先度 | プラットフォーム備考 |
|--------------|------|-------|-------------------|
| `stack` | 縦/横スタック | P0 | SwiftUI VStack/HStack |
| `grid` | CSSグリッド風レイアウト | P0 | LazyVGrid/LazyHGrid |
| `scroll_view` | スクロール可能コンテナ | P0 | ネイティブスクロールビュー |
| `spacer` | 柔軟なスペース | P0 | SwiftUI Spacer |
| `divider` | 視覚的区切り | P1 | - |
| `card` | 影付きカードコンテナ | P1 | - |
| `aspect_ratio` | 固定アスペクト比コンテナ | P1 | - |
| `safe_area` | セーフエリアインセット | P1 | iOSノッチ、Androidカットアウト |

#### 6.3 ナビゲーションコンポーネント

| コンポーネント | 説明 | 優先度 | プラットフォーム備考 |
|--------------|------|-------|-------------------|
| `nav_bar` | ナビゲーションバー | P0 | UINavigationBar, Toolbar |
| `tab_bar` | タブナビゲーション | P0 | UITabBar, BottomNavigation |
| `drawer` | サイドドロワー/メニュー | P1 | NavigationDrawer |
| `breadcrumb` | パンくずナビゲーション | P2 | Web向け |
| `pagination` | ページナビゲーション | P2 | - |

#### 6.4 フィードバックコンポーネント

| コンポーネント | 説明 | 優先度 | プラットフォーム備考 |
|--------------|------|-------|-------------------|
| `alert` | アラートダイアログ | P0 | ネイティブアラート |
| `toast` | トースト通知 | P0 | SnackBar, Toast |
| `modal` | モーダルダイアログ | P0 | Sheet, Dialog |
| `progress` | プログレスインジケーター | P1 | 線形/円形 |
| `spinner` | ローディングスピナー | P1 | ActivityIndicator |
| `skeleton` | ローディングプレースホルダー | P2 | - |
| `badge` | 通知バッジ | P1 | - |

#### 6.5 データ表示コンポーネント

| コンポーネント | 説明 | 優先度 | プラットフォーム備考 |
|--------------|------|-------|-------------------|
| `table` | データテーブル | P1 | - |
| `avatar` | ユーザーアバター | P1 | - |
| `icon` | アイコンコンポーネント | P0 | SF Symbols, Material Icons |
| `tag` | ラベル/タグ | P1 | Chip |
| `tooltip` | ホバーツールチップ | P2 | Web向け |
| `accordion` | 展開可能セクション | P1 | DisclosureGroup |
| `carousel` | 画像カルーセル | P2 | - |

### 成功基準

- [x] Zigコアで30種類以上のコンポーネント型を実装
- [x] Web/WASMプラットフォームで全P0コンポーネントが動作
- [x] 例を含むコンポーネントドキュメント（component-showcase）
- [x] コンポーネントのビジュアルリグレッションテスト
- [x] アクセシビリティサポート（ARIA、VoiceOver、TalkBack）
- [x] ネイティブプラットフォーム対応（iOS、Android、Windows）

---

## Phase 7: ルーティングシステム (v0.6.0) ✅ 完了

### 概要

各プラットフォームのナビゲーションパラダイムを尊重しながら、ナビゲーション、ディープリンク、URL管理を処理するクロスプラットフォームルーティングシステムを実装します。

### アーキテクチャ

```
┌─────────────────────────────────────────────────────────────┐
│                    Zylix Router (Zig Core)                  │
├─────────────────────────────────────────────────────────────┤
│  ルート定義        │  ルートマッチング  │  ナビゲーション状態  │
│  - パスパターン    │  - URL解析        │  - 履歴スタック      │
│  - パラメータ      │  - ワイルドカード  │  - 現在のルート      │
│  - ガード         │  - 正規表現       │  - パラメータ        │
└─────────────────────────────────────────────────────────────┘
                              │
                         C ABIレイヤー
                              │
     ┌────────────┬───────────┼───────────┬────────────┐
     ▼            ▼           ▼           ▼            ▼
┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐
│   iOS   │ │ Android │ │ Windows │ │  Linux  │ │   Web   │
│ NavStack│ │NavCompose│ │ NavView │ │GtkStack │ │History  │
└─────────┘ └─────────┘ └─────────┘ └─────────┘ └─────────┘
```

### 主要機能

#### 7.1 ルート定義

```zig
pub const Route = struct {
    path: []const u8,           // "/users/:id/posts"
    component_id: u32,          // このルートのルートコンポーネント
    title: ?[]const u8,         // ページタイトル
    meta: RouteMeta,            // メタデータ
    guards: []const RouteGuard, // ナビゲーションガード
    children: []const Route,    // ネストされたルート
};
```

### プラットフォーム統合

| プラットフォーム | ナビゲーション方式 | ディープリンク対応 |
|--------------|-----------------|-----------------|
| iOS | NavigationStack + path | Universal Links |
| Android | Navigation Compose | App Links |
| macOS | NavigationSplitView | カスタムURLスキーム |
| Windows | フレームナビゲーション | プロトコルハンドラー |
| Linux | GtkStack切り替え | D-Busアクティベーション |
| Web | History API | URLルーティング |

### 成功基準

- [ ] パスパターンとパラメータ付きルート定義
- [ ] 戻る/進むサポート付きナビゲーション履歴
- [ ] 全6プラットフォームでディープリンク
- [ ] 認証用ルートガード
- [ ] ネストされたルートサポート
- [ ] クエリ文字列処理

---

## Phase 8: 非同期処理のサポート (v0.6.0) ✅ 完了

### 概要

C ABI互換性を維持しながら、HTTPリクエスト、ファイルI/O、バックグラウンドタスクなどの非同期操作を処理するためのasync/awaitスタイルパターンをZigで実装します。

### アーキテクチャ

```
┌─────────────────────────────────────────────────────────────┐
│                  Zylix Async Runtime (Zig Core)             │
├─────────────────────────────────────────────────────────────┤
│   タスクキュー    │   Promise/Future  │   エグゼキュータプール │
│   - 優先度       │   - 状態マシン     │   - スレッドプール    │
│   - キャンセル   │   - チェーン      │   - ワークスティーリング│
│   - タイムアウト │   - エラー処理    │   - ロードバランシング │
└─────────────────────────────────────────────────────────────┘
```

### 主要機能

#### 8.1 Future/Promiseパターン

```zig
pub fn Future(comptime T: type) type {
    return struct {
        const Self = @This();

        state: enum { pending, resolved, rejected },
        value: ?T,
        error_info: ?ErrorInfo,

        pub fn then(self: *Self, callback: *const fn (T) void) *Self;
        pub fn catch(self: *Self, callback: *const fn (ErrorInfo) void) *Self;
        pub fn await(self: *Self) !T;
        pub fn cancel(self: *Self) void;
    };
}
```

#### 8.2 HTTPクライアント

```zig
pub const HttpClient = struct {
    pub fn get(url: []const u8) *Future(Response);
    pub fn post(url: []const u8, body: []const u8) *Future(Response);
    pub fn put(url: []const u8, body: []const u8) *Future(Response);
    pub fn delete(url: []const u8) *Future(Response);
};
```

### 成功基準

- [ ] チェーン付きFuture/Promiseパターン
- [ ] HTTP GET/POST/PUT/DELETEサポート
- [ ] JSONレスポンス解析
- [ ] バックグラウンドタスクスケジューリング
- [ ] キャンセルとタイムアウトサポート
- [ ] 適切な伝播を伴うエラー処理

---

## Phase 9: Hot Reload (v0.6.0) ✅ 完了

### 概要

フルリビルドサイクルなしで高速なイテレーションを可能にする開発用ホットリロード機能を実装します。コード更新中もアプリケーション状態を維持します。

### アーキテクチャ

```
┌─────────────────────────────────────────────────────────────┐
│                    開発サーバー                              │
├─────────────────────────────────────────────────────────────┤
│  ファイル監視    │   ビルドパイプライン  │   状態スナップショット │
│  - inotify      │   - インクリメンタル   │   - シリアライズ      │
│  - FSEvents     │   - 高速コンパイル    │   - リストア          │
│  - ReadDirChangesW│  - ホットパッチ     │   - 差分マージ        │
└─────────────────────────────────────────────────────────────┘
```

### CLIコマンド

```bash
# ホットリロード付き開発サーバー起動
zylix dev --platform web --port 3000

# iOSシミュレーター用監視とリビルド
zylix dev --platform ios-sim --hot

# 全プラットフォーム対応開発サーバー
zylix dev --all --port 3000
```

### 成功基準

- [ ] ファイル変更検出 < 100ms
- [ ] 小さな変更のインクリメンタルリビルド < 1秒
- [ ] リロード間での状態保持
- [ ] ソースマッピング付きエラーオーバーレイ
- [ ] 開発モードで全6プラットフォームで動作

---

## Phase 10: サンプルアプリケーション (v0.6.0) ✅ 完了

### 概要

全プラットフォームでZylixの実際の使用法を示す包括的なサンプルアプリケーションを作成し、ドキュメントと開発者向けテンプレートの両方として機能させます。

### サンプルアプリケーション

#### 10.1 拡張Todoアプリ（初級）

**現在**: 追加/削除機能付き基本的なTodoリスト
**拡張版**:
- カテゴリとタグ
- 通知付き期日
- 検索とフィルター
- クラウド同期（オプション）
- オフラインサポート
- ダーク/ライトテーマ

#### 10.2 ECアプリ（中級）

**機能**:
- 検索付き商品カタログ
- カテゴリナビゲーション
- ショッピングカート
- ユーザー認証
- 注文履歴
- 決済連携（モック）

#### 10.3 ダッシュボードアプリ（中級）

**機能**:
- リアルタイムデータ可視化
- チャートとグラフ
- ソート/フィルター付きデータテーブル
- CSV/PDFエクスポート
- ユーザー設定
- レスポンシブレイアウト

#### 10.4 チャットアプリ（上級）

**機能**:
- リアルタイムメッセージング
- ユーザープレゼンス
- メッセージ履歴
- ファイル添付
- プッシュ通知
- エンドツーエンド暗号化（オプション）

#### 10.5 メモアプリ（上級）

**機能**:
- リッチテキスト編集
- Markdownサポート
- フォルダ整理
- 全文検索
- クラウド同期
- 共有/エクスポート

### 成功基準

- [ ] 全5つのサンプルアプリが全プラットフォームで機能
- [ ] 各アプリの包括的なドキュメント
- [ ] ステップバイステップのチュートリアル
- [ ] パターンを説明するコードコメント
- [ ] パフォーマンスベンチマーク

---

## Phase 11a: テスト基盤 & 言語バインディング (v0.8.1) ✅ 完了

### 概要

クロスプラットフォームE2Eテストフレームワーク、watchOS対応、TypeScript/Python言語バインディングを実装しました。

### 実装完了

#### 11a.1 watchOS サポート
- ✅ Apple Watch デバイスタイプ (Series 9/10, Ultra 2, SE)
- ✅ Digital Crown 回転操作
- ✅ サイドボタン (シングル/ダブルプレス)
- ✅ コンパニオンデバイス (ペアリング情報取得)
- ✅ watchOS シミュレータ対応

#### 11a.2 言語バインディング
- ✅ **TypeScript**: `@zylix/test` npm パッケージ
  - 全プラットフォームドライバー (Web, iOS, watchOS, Android, macOS)
  - 10種類のセレクター
  - 完全な型定義
  - ESM + CommonJS デュアルエクスポート
- ✅ **Python**: `zylix-test` PyPI パッケージ
  - async/await 対応
  - 全プラットフォームドライバー
  - mypy strict 対応型アノテーション
  - PEP 561 型付きパッケージ

#### 11a.3 CI/CD
- ✅ GitHub Actions ワークフロー
  - Core ビルド (Ubuntu, macOS, Windows)
  - iOS/watchOS ビルド (Swift)
  - Android ビルド (Kotlin/Gradle)
  - Windows ビルド (.NET 8.0)
  - Web テスト (Node.js 20)
  - ドキュメントビルド (Hugo)
- ✅ リリースワークフロー

#### 11a.4 E2E テスト
- ✅ E2E テストフレームワーク (`core/src/test/e2e/`)
- ✅ プラットフォーム別サンプルデモ (`samples/test-demos/`)

### 成功基準

- [x] watchOS Digital Crown/サイドボタン対応
- [x] TypeScript/Python 言語バインディング
- [x] 全6プラットフォームでの CI/CD
- [x] E2E テストフレームワーク
- [x] プラットフォーム別サンプルデモ

---

## Phase 11b: 組み込みAI - Zylix AI (v0.9.0)

### 概要

オンデバイスLLM/VLM推論を実現する組み込みAI機能を実装します。プライバシー保護とオフライン動作を重視します。

### 計画機能

#### 11b.1 埋め込みモデル
- Qwen3-Embedding-0.6B 統合
- Sentence Transformers サポート
- セマンティック検索

#### 11b.2 言語モデル
- Qwen3 シリーズ (0.6B-4B)
- Phi-3/Phi-4 mini モデル
- Gemma 2B/7B
- Llama 3.2 (1B/3B)

#### 11b.3 ビジョン言語モデル (VLM)
- Qwen2-VL
- LLaVA
- PaliGemma

#### 11b.4 プラットフォームバックエンド
- iOS: Core ML, Metal, Apple Intelligence API
- Android: ML Kit, NNAPI, TensorFlow Lite
- Web/WASM: WebGPU, ONNX.js, WebNN
- Desktop: GGML/llama.cpp, ONNX Runtime

### 成功基準

- [ ] オンデバイス推論 (iOS/Android/Desktop)
- [ ] セマンティック検索機能
- [ ] テキスト生成/補完
- [ ] 画像理解 (VLM)
- [ ] 音声文字起こし (Whisper)

---

## Phase 12: デバイス機能 & ジェスチャー (v0.10.0) ✅ 完了

### 概要

クロスプラットフォームのデバイス機能と高度なジェスチャー認識システム。ハードウェアアクセス（GPS、カメラ、センサー）とタッチ操作（タップ、スワイプ、ピンチ、ドラッグアンドドロップ）の統一APIを提供します。

### 実装完了

#### 12.1 デバイス機能モジュール
- ✅ **位置情報サービス** (`location.zig`)
  - GPS/位置情報更新（精度設定可能）
  - ジオフェンシング（入退出監視）
  - ジオコーディング（住所 ↔ 座標変換）
  - Haversine公式による距離計算

- ✅ **カメラアクセス** (`camera.zig`)
  - 写真撮影（品質設定）
  - 動画録画
  - 前面/背面カメラ切り替え
  - フラッシュとフォーカス制御

- ✅ **センサー** (`sensors.zig`)
  - 加速度計、ジャイロスコープ、磁力計
  - 統合デバイスモーション（姿勢：ピッチ、ロール、ヨー）
  - 気圧計（気圧、高度）
  - 歩数計（歩数、距離）
  - 心拍数（watchOS）
  - コンパス方位

- ✅ **通知** (`notifications.zig`)
  - ローカル通知（即時、間隔、カレンダー、位置トリガー）
  - プッシュ通知トークン登録
  - 通知カテゴリとアクション
  - カスタムサウンド

- ✅ **オーディオ** (`audio.zig`)
  - オーディオ再生（位置/長さ）
  - オーディオ録音（品質設定）
  - セッションカテゴリ（アンビエント、再生、録音）

- ✅ **バックグラウンド処理** (`background.zig`)
  - バックグラウンドタスクスケジューリング
  - バックグラウンドフェッチ/同期
  - バックグラウンド転送（アップロード/ダウンロード）
  - タスク制約（ネットワーク、充電、バッテリー）

- ✅ **ハプティクス** (`haptics.zig`)
  - インパクトフィードバック（ライト、ミディアム、ヘビー、ソフト、リジッド）
  - 通知フィードバック（成功、警告、エラー）
  - カスタムハプティックパターン

- ✅ **権限** (`permissions.zig`)
  - 全デバイス機能の統一権限API
  - 権限ステータス追跡
  - Android向け理由説明サポート

#### 12.2 ジェスチャー認識モジュール
- ✅ **ジェスチャータイプ** (`gesture/types.zig`)
  - Point、Touch、TouchEvent構造体
  - GestureStateマシン（possible、began、changed、ended、cancelled、failed）
  - SwipeDirection、Velocity、Transform型

- ✅ **ジェスチャー認識器** (`gesture/recognizers.zig`)
  - TapRecognizer（シングル/マルチタップ）
  - LongPressRecognizer（設定可能な長さ）
  - PanRecognizer（速度付きドラッグ）
  - SwipeRecognizer（方向スワイプ）
  - PinchRecognizer（ズームジェスチャー）
  - RotationRecognizer（回転ジェスチャー）

- ✅ **ドラッグアンドドロップ** (`gesture/drag_drop.zig`)
  - プラットフォーム対応の開始方法（モバイル：長押し、デスクトップ：直接）
  - ドロップターゲット登録
  - データタイプ（テキスト、URL、ファイル、画像、カスタム）
  - ドロップ操作（コピー、移動、リンク）

### 成功基準

- [x] Zigコアでデバイス機能APIを実装
- [x] 8つのデバイス機能モジュール完了
- [x] 6種類の認識器を備えたジェスチャー認識システム
- [x] プラットフォーム対応ドラッグアンドドロップシステム
- [x] 全モジュールのユニットテスト
- [x] 全プラットフォームで同一API

---

## Phase 13: アニメーションシステム (v0.11.0) ✅ 完了

### 概要

ベクターアニメーション（Lottie）とLive2Dキャラクターアニメーションをサポートする包括的なアニメーションシステムを実装します。

### 計画機能

#### 13.1 Lottie ベクターアニメーション
- [Lottie](https://lottiefiles.com/jp/what-is-lottie) アニメーション再生
- JSONベースのアニメーションフォーマット対応
- アニメーション制御API（再生、一時停止、シーク、ループ）
- アニメーションイベントとコールバック
- レスポンシブなスケーリングと変形
- プラットフォームネイティブ最適化
  - iOS: Core Animation / Lottie-ios
  - Android: Lottie-android
  - Web: lottie-web / Bodymovin
  - Desktop: クロスプラットフォーム Lottie レンダラー

#### 13.2 Live2D 統合
- [Cubism SDK](https://www.live2d.com/sdk/) 統合 (v5-r.4.1)
- Live2D モデルの読み込みとレンダリング
- モーション再生とブレンディング
- 表情システム
- 物理シミュレーション（髪、服）
- 視線追跡とリップシンク
- プラットフォーム固有バックエンド
  - iOS/macOS: Metal レンダラー
  - Android: OpenGL ES レンダラー
  - Windows: DirectX/OpenGL レンダラー
  - Web: WebGL レンダラー

> **ライセンス要件**: Live2D Cubism SDKは[Live2D Proprietary Software License](https://www.live2d.com/terms/live2d-proprietary-software-license-agreement/)に基づき、再配布に制限があります。Cubism SDKを使用したコンテンツの商用リリースには、[SDK出版許諾契約](https://www.live2d.com/terms/publication-license-agreement/)への同意と関連する支払いが必要です。配布前のライセンスに関するお問い合わせは[Live2D](https://www.live2d.com/contact/)までご連絡ください。

#### 13.3 アニメーションユーティリティ
- タイムラインベースのアニメーションシーケンス
- イージング関数ライブラリ
- アニメーションステートマシン
- アニメーション間のトランジション効果
- パフォーマンスプロファイリングツール

### 成功基準

- [ ] 全プラットフォームでLottieアニメーション再生可能
- [ ] Live2Dモデルが正しくレンダリング
- [ ] 複雑なアニメーションで16ms未満のフレーム時間
- [ ] アニメーションイベントシステムが機能
- [ ] 包括的なアニメーションAPIドキュメント

---

## Phase 14: 3Dグラフィックスエンジン (v0.12.0) ✅ 完了

### 概要

[Three.js](https://github.com/mrdoob/three.js) と [Babylon.js](https://github.com/BabylonJS/Babylon.js) にインスパイアされた、ハードウェアアクセラレーション対応の3Dグラフィックスエンジンを実装します。

### 計画機能

#### 14.1 コア3Dエンジン
- シーングラフ管理
- カメラシステム（透視投影、正投影）
- ライティング（アンビエント、ディレクショナル、ポイント、スポット）
- マテリアルとシェーダー
- メッシュジオメトリプリミティブ
- 3Dモデル読み込み（glTF、OBJ、FBX）
- テクスチャマッピングとUV座標

#### 14.2 レンダリングパイプライン
- プラットフォームネイティブレンダリングバックエンド
  - iOS/macOS: Metal
  - Android: Vulkan / OpenGL ES
  - Windows: DirectX 12 / Vulkan
  - Linux: Vulkan / OpenGL
  - Web: WebGL 2.0 / WebGPU
- ディファードレンダリング
- シャドウマッピング
- ポストプロセスエフェクト
- アンチエイリアス（MSAA、FXAA、TAA）

#### 14.3 高度な機能
- スケルタルアニメーション
- パーティクルシステム
- 物理統合（衝突検出）
- レイキャスティングとピッキング
- Level of Detail (LOD)
- インスタンスレンダリング
- オクルージョンカリング

#### 14.4 開発者ツール
- 3Dシーンインスペクター
- パフォーマンスプロファイラー
- シェーダーエディター
- アセットインポートパイプライン

### 成功基準

- [ ] 全プラットフォームで3Dシーンがレンダリング
- [ ] glTFモデル読み込み機能
- [ ] 中程度の複雑さのシーンで60fps
- [ ] ライティングとシャドウが動作
- [ ] 完全な3D APIドキュメント

---

## Phase 15: ゲーム開発プラットフォーム (v0.13.0) 🚧 進行中

### 概要

[PIXI.js](https://github.com/pixijs/pixijs) にインスパイアされた包括的なゲーム開発プラットフォーム。[Matter.js](https://github.com/liabru/matter-js) ベースの物理エンジンと、効果音・BGM用の完全なオーディオシステムを内蔵します。

### 計画機能

#### 15.1 2Dゲームエンジン
- バッチング対応スプライトシステム
- テクスチャアトラスとスプライトシート
- タイルマップ（直交、等角、六角形）
- シーン管理
- 固定タイムステップのゲームループ
- 入力処理（キーボード、マウス、タッチ、ゲームパッド）
- 衝突検出（AABB、円、ポリゴン）

#### 15.2 物理エンジン
- 剛体力学（Matter.jsインスパイア）
- 衝突検出と応答
- 制約とジョイント
  - 距離、回転、プリズマティック、溶接
- 力と衝撃
- 重力と摩擦
- スリーピングボディ最適化
- 連続衝突検出（CCD）
- 物理デバッグレンダラー

#### 15.3 オーディオシステム
- 効果音再生
  - ワンショットサウンド
  - ループサウンド
  - 位置オーディオ（2D/3D）
- BGM（バックグラウンドミュージック）
  - 大容量ファイルのストリーミング再生
  - トラック間のクロスフェード
  - プレイリストサポート
- オーディオ制御
  - ボリューム制御（マスター、音楽、SFX）
  - ピッチと速度調整
  - フェードイン/アウト
  - ダッキング（会話中の音楽低減）
- オーディオフォーマット
  - MP3、OGG、WAV、AAC
  - プラットフォームネイティブコーデック
- プラットフォームバックエンド
  - iOS: AVAudioEngine
  - Android: AudioTrack / Oboe
  - Web: Web Audio API
  - Desktop: OpenAL / miniaudio

#### 15.4 ゲームユーティリティ
- Entity-Component-System (ECS) アーキテクチャ
- オブジェクトプーリング
- ゲーム状態用ステートマシン
- トゥイーンライブラリ
- パーティクルエフェクト（2D）
- カメラシステム（追従、シェイク、ズーム）
- ゲーム状態のセーブ/ロード
- 実績システム

### 成功基準

- [ ] 60fpsで2Dゲームレンダリング
- [ ] 物理シミュレーションが安定かつ正確
- [ ] 全プラットフォームでオーディオ再生
- [ ] 完全なゲーム開発チュートリアル
- [ ] 機能を実証するサンプルゲーム

---

## Phase 16: データベースサポート (v0.14.0)

### 概要

SQLite、MySQL、PostgreSQL、Turso (libSQL) をサポートする包括的なデータベース接続レイヤー。WASM を含むすべてのプラットフォームで統一された API を提供します。

### 計画機能

#### 16.1 SQLite サポート
- 組み込み SQLite エンジン
- インメモリデータベース
- ファイルベースデータベース
- WAL モードサポート
- ユーザー定義関数
- 仮想テーブル
- 全文検索 (FTS5)
- JSON1 拡張

#### 16.2 MySQL サポート
- MySQL プロトコル実装
- プリペアドステートメント
- 複数結果セット
- バイナリプロトコル
- 接続圧縮
- SSL/TLS サポート
- ストアドプロシージャ
- トランザクション

#### 16.3 PostgreSQL サポート
- 完全なプロトコル実装
- 全データ型サポート
- LISTEN/NOTIFY
- COPY 操作
- 配列型
- JSON/JSONB 操作
- 全文検索
- プリペアドステートメント

#### 16.4 Turso / libSQL サポート
- [Turso](https://turso.tech/) クラウドデータベース
- [libSQL](https://github.com/tursodatabase/libsql) 組み込みモード
- エッジ最適化クエリ
- 組み込みレプリカ
- HTTP API サポート
- SQLite 互換性
- グローバル分散
- 自動スケーリング

#### 16.5 接続管理
- コネクションプーリング
- 接続文字列パース
- SSL/TLS サポート
- 自動再接続
- トランザクション管理
- プリペアドステートメント

#### 16.6 クエリビルダー
- 型安全なクエリ構築
- コンパイル時 SQL 検証
- パラメータバインディング
- 結果マッピング
- マイグレーションサポート

### プラットフォーム実装

| プラットフォーム | SQLite | MySQL | PostgreSQL | Turso/libSQL |
|----------------|--------|-------|------------|--------------|
| ネイティブ (iOS, Android, macOS, Linux, Windows) | 組み込み | TCP | TCP | 組み込み/HTTP |
| Web/WASM | OPFS/IndexedDB | HTTP プロキシ | HTTP プロキシ | HTTP |
| エッジ (Cloudflare, Vercel) | D1 | - | TCP (Hyperdrive) | HTTP |

### アーキテクチャ

```
┌─────────────────────────────────────────────────────────────┐
│                  Zylix Database (Zig Core)                  │
├─────────────────────────────────────────────────────────────┤
│  コネクションプール│  クエリビルダー  │  トランザクション管理 │
│  - 最大接続数     │  - 型安全       │  - ACID 準拠        │
│  - ヘルスチェック │  - コンパイル時SQL│  - セーブポイント   │
│  - 自動再接続    │  - マイグレーション│  - ロールバック     │
└─────────────────────────────────────────────────────────────┘
                              │
                         C ABI レイヤー
                              │
     ┌────────────┬───────────┼───────────┬────────────┐
     ▼            ▼           ▼           ▼            ▼
┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐
│ SQLite  │ │  MySQL  │ │PostgreSQL│ │ Turso  │ │  WASM   │
│  組込み  │ │  TCP    │ │   TCP   │ │  HTTP  │ │ プロキシ │
└─────────┘ └─────────┘ └─────────┘ └─────────┘ └─────────┘
```

### 成功基準

- [ ] 4つのデータベースすべてに接続可能
- [ ] 型安全なクエリビルダー
- [ ] トランザクションサポート
- [ ] コネクションプーリング動作
- [ ] WASM でのデータベースアクセス（プロキシ経由）
- [ ] マイグレーションシステム機能
- [ ] データベースサンプルアプリケーション

---

## Phase 17: アプリ統合API (v0.15.0)

### 概要

一般的なアプリ統合ニーズのための統一API：アプリ内課金、広告、永続ストレージ、アプリライフサイクル管理、リアルタイム処理向けの拡張カメラ/オーディオ機能。

### 計画機能

#### 17.1 アプリ内課金 (IAP) 抽象化
- プラットフォーム横断の統一購入フロー
- 商品カタログクエリ
- 購入と復元機能
- エンタイトルメント検証
- レシート検証

```zig
pub const Store = struct {
    pub fn getProducts(product_ids: []const []const u8) *Future([]Product);
    pub fn purchase(product_id: []const u8) *Future(PurchaseResult);
    pub fn restore() *Future(RestoreResult);
    pub fn hasEntitlement(product_id: []const u8) bool;
};
```

#### 17.2 広告抽象化
- バナー広告（プレースメントによる表示/非表示）
- インタースティシャル広告
- リワード動画広告
- GDPR/プライバシー準拠ヘルパー

```zig
pub const Ads = struct {
    pub fn showBanner(placement_id: []const u8) void;
    pub fn hideBanner(placement_id: []const u8) void;
    pub fn showInterstitial(placement_id: []const u8) *Future(AdResult);
    pub fn showRewarded(placement_id: []const u8) *Future(RewardResult);
};
```

#### 17.3 KeyValueStore
- 永続的なキーバリューストレージ
- 型安全なアクセサー（bool、int、float、string）
- デフォルト値サポート
- 非同期バッチ操作

```zig
pub const KeyValueStore = struct {
    pub fn getBool(key: []const u8, default: bool) bool;
    pub fn getFloat(key: []const u8, default: f32) f32;
    pub fn getString(key: []const u8, default: []const u8) []const u8;
    pub fn putBool(key: []const u8, value: bool) void;
    pub fn putFloat(key: []const u8, value: f32) void;
    pub fn putString(key: []const u8, value: []const u8) void;
};
```

#### 17.4 アプリライフサイクルフック
- フォアグラウンド/バックグラウンド状態コールバック
- 終了ハンドラー
- メモリ警告通知
- 状態復元サポート

```zig
pub const AppLifecycle = struct {
    pub fn onForeground(callback: *const fn () void) void;
    pub fn onBackground(callback: *const fn () void) void;
    pub fn onTerminate(callback: *const fn () void) void;
    pub fn onMemoryWarning(callback: *const fn () void) void;
};
```

#### 17.5 モーションフレームプロバイダー
- モーショントラッキング用の低解像度カメラフレーム
- プレビュー不要（バックグラウンド処理）
- 設定可能なフレームレートと解像度
- モーション重心検出サポート

```zig
pub const MotionFrameProvider = struct {
    pub fn start(config: MotionFrameConfig, on_frame: *const fn (MotionFrame) void) void;
    pub fn stop() void;
};

pub const MotionFrameConfig = struct {
    target_fps: u8 = 15,
    resolution: Resolution = .low,
    pixel_format: PixelFormat = .grayscale,
};
```

#### 17.6 低レイテンシオーディオクリッププレイヤー
- 最小レイテンシでの短いオーディオクリップ再生
- 即時再生のためのプリロードサポート
- クリップごとのボリューム制御
- 複数同時再生

```zig
pub const AudioClipPlayer = struct {
    pub fn preload(clips: []const AudioClip) *Future(void);
    pub fn play(clip_id: []const u8, volume: f32) void;
    pub fn stop(clip_id: []const u8) void;
    pub fn stopAll() void;
};
```

### プラットフォーム実装

| 機能 | iOS | Android | Web | Desktop |
|-----|-----|---------|-----|---------|
| IAP | StoreKit 2 | Play Billing | - | - |
| 広告 | AdMob/AppLovin | AdMob/AppLovin | - | - |
| KeyValueStore | UserDefaults | SharedPreferences | localStorage | ファイルベース |
| ライフサイクル | UIApplication | Activity/Lifecycle | visibilitychange | ネイティブイベント |
| モーションフレーム | AVFoundation | CameraX ImageAnalysis | getUserMedia | プラットフォームカメラ |
| オーディオクリップ | AVAudioEngine | AudioTrack/Oboe | Web Audio API | miniaudio |

### 成功基準

- [ ] iOSとAndroidでIAP購入・復元が動作
- [ ] バナー広告が正しく表示
- [ ] KeyValueStoreがアプリ再起動後も永続化
- [ ] ライフサイクルフックが状態変更から1秒以内にトリガー
- [ ] モーションフレームが15fpsで安定動作
- [ ] オーディオクリップのレイテンシが150ms未満

---

## Phase 18: 開発者ツール (v0.16.0)

### 概要

Zylixアプリケーション向けの包括的な開発者ツール：プロジェクト管理CLI、スキャフォールディングシステム、ビルドオーケストレーション、テンプレートカタログ、ライブプレビュー機能。

### 計画機能

#### 18.1 プロジェクトスキャフォールディングAPI
- 7プラットフォームすべてのプロジェクトレイアウト作成
- テンプレートベースの初期化
- 設定生成
- 依存関係解決

```zig
pub const Project = struct {
    pub fn create(template_id: []const u8, targets: []const Target, output_dir: []const u8) *Future(ProjectId);
    pub fn validate(project_id: ProjectId) *Future(ValidationResult);
    pub fn getInfo(project_id: ProjectId) ProjectInfo;
};
```

#### 18.2 ビルドオーケストレーションAPI
- マルチターゲットビルド実行
- ビルド設定管理
- 進捗とログストリーミング
- 並列ビルドサポート

```zig
pub const Build = struct {
    pub fn start(project_id: ProjectId, target: Target, config: BuildConfig) *Future(BuildId);
    pub fn cancel(build_id: BuildId) void;
    pub fn getStatus(build_id: BuildId) BuildStatus;
    pub fn onProgress(build_id: BuildId, callback: *const fn (BuildProgress) void) void;
    pub fn onLog(build_id: BuildId, callback: *const fn (LogEntry) void) void;
};
```

#### 18.3 ビルドアーティファクトクエリAPI
- アーティファクトパス取得
- メタデータアクセス（サイズ、ハッシュ、タイムスタンプ）
- 署名ステータス情報
- エクスポートとパッケージング

```zig
pub const Artifacts = struct {
    pub fn getArtifacts(build_id: BuildId) *Future([]Artifact);
    pub fn getMetadata(artifact_path: []const u8) ArtifactMetadata;
    pub fn export(artifact_path: []const u8, destination: []const u8) *Future(void);
};
```

#### 18.4 ターゲット機能マトリックスAPI
- ターゲットごとのサポート機能クエリ
- ランタイム機能検出
- 機能互換性検証
- 動的UIフィールド設定

```zig
pub const Targets = struct {
    pub fn getCapabilities() CapabilityMatrix;
    pub fn supportsFeature(target: Target, feature: Feature) bool;
    pub fn getRequiredInputs(target: Target) []InputSpec;
};
```

#### 18.5 テンプレートカタログAPI
- 利用可能なプロジェクトテンプレート一覧
- テンプレートメタデータと要件
- カスタムテンプレート登録
- テンプレートバージョニング

```zig
pub const Templates = struct {
    pub fn list() []Template;
    pub fn getDetails(template_id: []const u8) TemplateDetails;
    pub fn register(template: CustomTemplate) *Future(void);
};
```

#### 18.6 ファイルウォッチャーAPI
- リアルタイムファイルシステム監視
- 設定可能なフィルターとパターン
- デバウンス付き変更イベント
- 再帰的ディレクトリ監視

```zig
pub const FileWatcher = struct {
    pub fn watch(path: []const u8, filters: WatchFilters) WatchId;
    pub fn unwatch(watch_id: WatchId) void;
    pub fn onChange(watch_id: WatchId, callback: *const fn (FileChange) void) void;
};
```

#### 18.7 コンポーネントツリーエクスポートAPI
- プロジェクトからコンポーネント階層を抽出
- JSON/構造化フォーマットエクスポート
- プロパティとバインディング情報
- ビジュアルプレビューサポート

```zig
pub const UI = struct {
    pub fn exportTree(project_id: ProjectId) *Future(ComponentTree);
    pub fn getComponentInfo(component_id: ComponentId) ComponentInfo;
};
```

#### 18.8 ライブプレビューブリッジAPI
- プレビューセッション起動
- ホットリロード統合
- マルチデバイスプレビュー
- デバッグオーバーレイサポート

```zig
pub const Preview = struct {
    pub fn open(project_id: ProjectId, target: Target) *Future(PreviewId);
    pub fn close(preview_id: PreviewId) void;
    pub fn refresh(preview_id: PreviewId) void;
    pub fn setDebugOverlay(preview_id: PreviewId, enabled: bool) void;
};
```

### CLIコマンド

```bash
# プロジェクトスキャフォールディング
zylix new my-app --template=app --targets=ios,android,web

# ビルドコマンド
zylix build --target=ios --config=release
zylix build --all --parallel

# 開発
zylix dev --target=web --port=3000
zylix preview --target=ios-sim

# テンプレート管理
zylix templates list
zylix templates add ./my-template
```

### 成功基準

- [ ] 7プラットフォームすべてで単一コマンドでプロジェクト作成
- [ ] ビルド開始/完了イベントがログ付きで発行
- [ ] アーティファクトパスとメタデータがクエリ可能
- [ ] ターゲット機能がハードコードなしでクエリ可能
- [ ] テンプレートカタログがAPI経由でアクセス可能
- [ ] ファイル変更がエディタに確実に反映
- [ ] コンポーネントツリーが手動パースなしでエクスポート可能
- [ ] プレビューが単一アクションで起動可能

---

## Phase 19: ノードベースUI (v0.17.0)

### 概要

[React Flow](https://reactflow.dev/) にインスパイアされたノードベースUIコンポーネント。ビジュアルワークフローエディタ、マインドマップ、データフロー図などを構築できます。

### 計画機能

#### 19.1 コアノードシステム
- ノードコンポーネント
  - カスタマイズ可能なノード形状
  - 入力/出力ハンドル（ポート）
  - ドラッグ＆ドロップ配置
  - ノードリサイズとグループ化
- エッジ（接続線）
  - 直線、ベジェ曲線、ステップ接続
  - アニメーション付きエッジ
  - カスタムラベルとスタイル
  - エッジの動的生成

#### 19.2 キャンバス機能
- インタラクティブキャンバス
  - パン（ドラッグでスクロール）
  - ズーム（ピンチ/スクロール）
  - ミニマップ表示
  - グリッドスナップ
- 選択と操作
  - 複数選択（矩形選択、Shift+クリック）
  - カット/コピー/ペースト
  - 元に戻す/やり直し
  - キーボードショートカット

#### 19.3 データフロー
- ノード間データ転送
- 計算グラフの実行
- リアクティブな更新伝播
- カスタムノードタイプ定義

### 成功基準

- [ ] 滑らかなパン/ズーム操作（60fps）
- [ ] 1000ノード以上のスケーラビリティ
- [ ] 直感的なノード接続体験
- [ ] ワークフローエディタのサンプルアプリ

---

## Phase 20: PDFサポート (v0.18.0)

### 概要

[pdf-nano](https://github.com/GregorBudweiser/pdf-nano) にインスパイアされたPDF処理機能。PDF生成、読み込み、編集をサポートします。

### 計画機能

#### 20.1 PDF生成
- 文書構造
  - ページ追加と管理
  - ページサイズと向き設定
  - 余白とレイアウト
- コンテンツ埋め込み
  - テキスト（フォント、サイズ、色）
  - 画像（JPEG、PNG、SVG）
  - 図形（線、矩形、円、パス）
  - テーブルとリスト
- フォント対応
  - 標準14フォント
  - TrueType/OpenTypeフォント埋め込み
  - 日本語フォント対応

#### 20.2 PDF読み込み
- PDF解析
  - テキスト抽出
  - 画像抽出
  - メタデータ取得
  - ページ情報取得
- コンテンツアクセス
  - ページごとのコンテンツストリーム
  - フォーム フィールド読み込み
  - 注釈の取得

#### 20.3 PDF編集
- ページ操作
  - ページの追加/削除/並べ替え
  - PDF結合/分割
  - ページの回転
- コンテンツ変更
  - テキスト注釈追加
  - スタンプ/ウォーターマーク
  - フォームフィールド入力

### 成功基準

- [ ] 高品質なPDF出力
- [ ] 全プラットフォームでの読み書き動作
- [ ] 日本語テキストの正確な表示
- [ ] PDFビューア/エディタのサンプルアプリ

---

## Phase 21: Excelサポート (v0.19.0) ✅ 完了

### 概要

Pure Zig による Office Open XML (xlsx) スプレッドシートのサポート。外部依存なしの完全自己完結型実装で、全Zylixプラットフォームで最大限のポータビリティを実現。

### 実装済み機能

#### 21.1 ワークブック管理 (`workbook.zig`) ✅
- 新規Excelワークブック作成
- メモリまたはファイルパスから既存XLSXファイルの解析
- ワークシートの追加/取得/削除
- 効率的な文字列保存のための共有文字列テーブル
- アクティブシートの追跡
- ドキュメントプロパティ（タイトル、作成者、件名、キーワード）

#### 21.2 ワークシート操作 (`worksheet.zig`) ✅
- 行/列またはA1記法によるセル管理
- 行の高さ設定（ポイント）
- 列幅設定（文字数）
- 行/列の非表示サポート
- セル結合範囲
- 使用範囲の自動追跡

#### 21.3 セル操作 (`cell.zig`) ✅
- 型安全なセル値（文字列、数値、真偽値、日付、時刻、日時、数式、エラー）
- A1記法の解析とフォーマット（A1, B2, AA100等）
- セル範囲サポート（A1:C10）
- スタイルインデックスのリンク

#### 21.4 スタイル (`style.zig`) ✅
- 重複排除機能付きスタイルマネージャー
- フォント: 名前、サイズ、太字、斜体、下線、取消線、色
- 塗りつぶし: none、solid、gray_125パターン（前景/背景色）
- 罫線: 左、右、上、下、対角線（スタイルと色）
- 配置: 水平（general、left、center、right、fill、justify）
- 配置: 垂直（top、center、bottom、justify、distributed）
- テキスト制御: 折り返し、縮小して全体を表示、回転、インデント
- 数値フォーマット: 組み込み + カスタムフォーマット文字列
- スタイルビルダーの流暢なAPI

#### 21.5 XLSX書き込み (`writer.zig`) ✅
- 適切な構造でのZIPファイル生成
- CRC-32チェックサム計算
- XMLパーツ生成（Content_Types、relationships、workbook、worksheets、styles、shared strings）
- ファイル出力またはバイトバッファ返却

#### 21.6 XLSX読み込み (`reader.zig`) ✅
- ZIPアーカイブ解析
- DEFLATE解凍サポート
- 共有文字列解析
- ワークブック/ワークシートXML解析
- セルタイプの検出と値抽出
- XMLエンティティデコード

### プラットフォーム実装

| プラットフォーム | バックエンド |
|----------------|------------|
| 全プラットフォーム | Pure Zig（外部依存なし） |

### 成功基準

- [x] Excel/LibreOfficeで開けるxlsxファイルの作成
- [x] 既存xlsxファイルの読み込み
- [x] セルタイプ: 文字列、数値、真偽値、日付、時刻、数式
- [x] スタイル: フォント、塗りつぶし、罫線、配置
- [x] Pure Zig実装（C依存なし）
- [ ] グラフと画像（将来の拡張）
- [ ] ストリーミングによる大容量ファイルサポート（将来の拡張）

---

## Phase 22: mBaaSサポート (v0.20.0)

### 概要

Firebase、Supabase、AWS Amplify などの主要な mBaaS (mobile Backend as a Service) プラットフォームとの統合を提供します。認証、データベース、ストレージ、プッシュ通知などのバックエンド機能を統一APIで利用可能にします。

### 計画機能

#### 22.1 Firebase 統合

- **Firebase Authentication**
  - メール/パスワード認証
  - ソーシャルログイン (Google, Apple, Facebook, Twitter)
  - 電話番号認証
  - 匿名認証
  - カスタムトークン認証

- **Cloud Firestore**
  - リアルタイムデータ同期
  - ドキュメント/コレクション操作
  - クエリとフィルタリング
  - オフラインサポート
  - トランザクション

- **Firebase Storage**
  - ファイルアップロード/ダウンロード
  - 進捗監視
  - メタデータ管理
  - セキュリティルール

- **Firebase Cloud Messaging (FCM)**
  - プッシュ通知送受信
  - トピックサブスクリプション
  - 通知ペイロード処理

- **その他のサービス**
  - Firebase Analytics
  - Firebase Crashlytics
  - Firebase Remote Config
  - Firebase App Check

#### 22.2 Supabase 統合

- **Supabase Auth**
  - メール/パスワード認証
  - マジックリンク
  - ソーシャルログイン (OAuth プロバイダー)
  - Row Level Security (RLS) 連携

- **Supabase Database (PostgreSQL)**
  - リアルタイムサブスクリプション
  - CRUD 操作
  - SQL クエリ
  - ストアドプロシージャ
  - PostgREST API 統合

- **Supabase Storage**
  - ファイルアップロード/ダウンロード
  - 署名付き URL
  - バケット管理
  - 画像変換 (リサイズ、最適化)

- **Supabase Edge Functions**
  - サーバーレス関数呼び出し
  - カスタムロジック実行

- **Supabase Realtime**
  - Broadcast チャンネル
  - Presence 機能
  - データベース変更リスナー

#### 22.3 AWS Amplify 統合

- **Amplify Auth (Cognito)**
  - ユーザープール管理
  - フェデレーテッドアイデンティティ
  - MFA サポート
  - OAuth/OIDC プロバイダー

- **Amplify DataStore**
  - オフラインファーストデータ同期
  - GraphQL API (AppSync)
  - リアルタイムサブスクリプション
  - 競合解決

- **Amplify Storage (S3)**
  - ファイル操作
  - アクセスレベル管理 (public, protected, private)
  - 署名付き URL

- **Amplify Push Notifications**
  - Amazon Pinpoint 統合
  - セグメント配信
  - 分析と追跡

- **その他のサービス**
  - Amplify Analytics
  - Amplify Predictions (AI/ML)
  - Amplify Geo (位置情報)

### 統一 API 設計

```zig
// 統一された mBaaS 認証 API
pub const Auth = struct {
    pub fn signInWithEmail(email: []const u8, password: []const u8) *Future(User);
    pub fn signInWithProvider(provider: AuthProvider) *Future(User);
    pub fn signOut() *Future(void);
    pub fn getCurrentUser() ?User;
    pub fn onAuthStateChange(callback: *const fn (?User) void) Subscription;
};

// 統一されたデータベース API
pub const Database = struct {
    pub fn collection(name: []const u8) Collection;
    pub fn doc(path: []const u8) Document;
    pub fn query(collection: Collection, filters: []const Filter) *Future([]Document);
    pub fn subscribe(query: Query, callback: DataCallback) Subscription;
};

// 統一されたストレージ API
pub const Storage = struct {
    pub fn upload(path: []const u8, data: []const u8) *Future(UploadResult);
    pub fn download(path: []const u8) *Future([]const u8);
    pub fn getUrl(path: []const u8) *Future([]const u8);
    pub fn delete(path: []const u8) *Future(void);
};
```

### プラットフォーム実装

| プラットフォーム | Firebase | Supabase | AWS Amplify |
|----------------|----------|----------|-------------|
| iOS | Firebase iOS SDK | supabase-swift | Amplify iOS |
| Android | Firebase Android SDK | supabase-kt | Amplify Android |
| Web | Firebase JS SDK | supabase-js | Amplify JS |
| macOS | Firebase iOS SDK | supabase-swift | Amplify iOS |
| Windows | Firebase C++ SDK | REST API | REST API |
| Linux | Firebase C++ SDK | REST API | REST API |

### 成功基準

- [ ] Firebase Authentication/Firestore/Storage 統合
- [ ] Supabase Auth/Database/Storage 統合
- [ ] AWS Amplify Auth/DataStore/Storage 統合
- [ ] 統一 API による抽象化レイヤー
- [ ] 全プラットフォームでのリアルタイム同期
- [ ] オフライン対応とデータ永続化
- [ ] mBaaS サンプルアプリケーション

---

## Phase 23: サーバーランタイム - Zylix Server (v0.21.0)

### 概要

Zylix Server - Zig で API とフルスタックアプリケーションを構築するためのサーバーサイドランタイム。Hono.js にインスパイアされ、共有 Zig コードによるクライアント・サーバー間の型安全な RPC を提供します。

### 計画機能

#### 23.1 HTTP サーバー
- 高性能 HTTP/1.1 と HTTP/2
- リクエスト/レスポンス処理
- ミドルウェアサポート
- 静的ファイル配信
- WebSocket サポート
- Server-Sent Events

#### 23.2 ルーティング
- パスベースルーティング
- ルートパラメータ
- クエリ文字列パース
- ルートグループ
- ミドルウェアチェーン
- エラーハンドリング

```zig
const app = zylix.server();

app.get("/users", handlers.listUsers);
app.get("/users/:id", handlers.getUser);
app.post("/users", handlers.createUser);
app.group("/api/v1", apiRoutes);
```

#### 23.3 型安全な RPC
- 共有型定義（クライアント ↔ サーバー）
- TypeScript 自動生成
- コンパイル時ルート検証
- リクエスト/レスポンスのシリアライズ

```zig
// shared/api.zig
pub const API = struct {
    pub const getUsers = zylix.endpoint(.GET, "/users", void, []User);
    pub const createUser = zylix.endpoint(.POST, "/users", CreateUserReq, User);
};

// クライアント: const users = try client.call(API.getUsers, {});
// サーバー: router.handle(API.getUsers, handlers.getUsers);
```

#### 23.4 ミドルウェア
- リクエストログ
- CORS 処理
- 認証（JWT、セッション）
- レート制限
- 圧縮
- エラーハンドリング

#### 23.5 サーバーサイドレンダリング
- コンポーネントの HTML レンダリング
- ハイドレーションサポート
- ストリーミングレスポンス
- テンプレートサポート

#### 23.6 開発ツール
- サーバーコードのホットリロード
- リクエストインスペクター
- API ドキュメント生成
- OpenAPI/Swagger サポート

### アーキテクチャ

```
┌─────────────────────────────────────────┐
│           Zylix アプリケーション          │
├─────────────────────────────────────────┤
│  クライアント (WASM) │ サーバー (Zig Native) │
├─────────────────┴───────────────────────┤
│         共有型定義 (api.zig)             │
├─────────────────────────────────────────┤
│              RPC レイヤー                │
└─────────────────────────────────────────┘
```

### 成功基準

- [ ] ルーティング付き HTTP サーバー
- [ ] 型安全な RPC 動作
- [ ] ミドルウェアシステム
- [ ] データベース統合
- [ ] フルスタックサンプルアプリケーション

---

## Phase 24: エッジアダプター (v0.22.0)

### 概要

Zylix Server をエッジコンピューティングプラットフォームにデプロイ。Zig サーバーコードをエッジランタイム向け WASM にコンパイルし、7つの主要エッジプラットフォーム用のアダプターを提供します。

### 計画機能

#### 24.1 Cloudflare Workers
- WASM ターゲットコンパイル
- Workers API バインディング
- KV ストレージ統合
- D1 データベースサポート
- Durable Objects
- R2 ストレージ
- Queues

```zig
// cloudflare/worker.zig
const zylix = @import("zylix-server");
const cf = @import("zylix-cloudflare");

pub fn fetch(req: cf.Request, env: cf.Env) !cf.Response {
    var app = zylix.server();
    app.use(cf.adapter(env));
    return app.handle(req);
}
```

#### 24.2 Vercel Edge Functions
- Edge Runtime ターゲット
- Vercel KV 統合
- Vercel Postgres (Neon 経由)
- Blob ストレージ
- Edge Config
- ISR (Incremental Static Regeneration)

#### 24.3 AWS Lambda
- Lambda カスタムランタイム
- Lambda@Edge サポート
- API Gateway 統合
- DynamoDB バインディング
- S3 統合
- SQS/SNS サポート
- EventBridge 統合

#### 24.4 Azure Functions
- Azure Functions カスタムハンドラー
- HTTP トリガー
- Azure Cosmos DB 統合
- Azure Blob Storage
- Azure Service Bus
- Azure Event Grid
- Durable Functions

```zig
// azure/function.zig
const zylix = @import("zylix-server");
const azure = @import("zylix-azure");

pub fn main() !void {
    var app = zylix.server();
    app.use(azure.adapter());
    try azure.serve(app);
}
```

#### 24.5 Deno Deploy
- Deno WASM サポート
- Deno KV 統合
- BroadcastChannel
- Cron トリガー
- Fresh フレームワーク互換

#### 24.6 Google Cloud Run
- コンテナベースデプロイ
- Cloud Firestore 統合
- Cloud Storage
- Pub/Sub 統合
- Cloud Tasks
- 自動スケーリング
- VPC コネクタ

```zig
// gcp/cloudrun.zig
const zylix = @import("zylix-server");
const gcp = @import("zylix-gcp");

pub fn main() !void {
    var app = zylix.server();
    app.use(gcp.adapter());
    const port = gcp.getPort() orelse 8080;
    try app.listen(port);
}
```

#### 24.7 Fastly Compute@Edge
- Fastly WASM ランタイム
- Config Store 統合
- KV Store
- Secret Store
- Fanout (リアルタイム)
- Image Optimizer 統合
- エッジ辞書

```zig
// fastly/compute.zig
const zylix = @import("zylix-server");
const fastly = @import("zylix-fastly");

pub fn main() !void {
    var app = zylix.server();
    app.use(fastly.adapter());
    try fastly.serve(app);
}
```

#### 24.8 統一 API
- プラットフォーム非依存コード
- 環境検出
- 機能検出
- グレースフルフォールバック
- プロバイダー切り替え

```zig
// 統一 API - どのプラットフォームでも動作
const store = try zylix.kv.connect();
try store.put("key", value);
const data = try store.get("key");

// 環境検出
const platform = zylix.edge.detectPlatform();
switch (platform) {
    .cloudflare => // Cloudflare 固有の処理,
    .vercel => // Vercel 固有の処理,
    .aws_lambda => // AWS Lambda 固有の処理,
    .azure => // Azure Functions 固有の処理,
    .deno => // Deno Deploy 固有の処理,
    .gcp => // Google Cloud Run 固有の処理,
    .fastly => // Fastly 固有の処理,
    else => // 汎用処理,
}
```

#### 24.9 ビルドツール
- プラットフォーム固有バンドル
- WASM 最適化
- Tree shaking
- ソースマップ
- デプロイ CLI
- マルチプラットフォーム同時デプロイ

```bash
# 各プラットフォーム向けビルド
zylix build --target=cloudflare
zylix build --target=vercel
zylix build --target=aws-lambda
zylix build --target=azure
zylix build --target=deno
zylix build --target=gcp
zylix build --target=fastly

# デプロイ
zylix deploy --platform=cloudflare
zylix deploy --platform=azure
zylix deploy --platform=gcp

# 複数プラットフォーム同時デプロイ
zylix deploy --platforms=cloudflare,vercel,aws-lambda
```

### プラットフォーム比較

| 機能 | Cloudflare | Vercel | AWS Lambda | Azure | Deno | GCP | Fastly |
|------|------------|--------|------------|-------|------|-----|--------|
| ランタイム | V8 Isolates | V8 Edge | Custom/WASM | Custom | V8 | Container | WASM |
| コールドスタート | ~0ms | ~0ms | 100-500ms | 100-500ms | ~0ms | 100-300ms | ~0ms |
| CPU 制限 | 10-50ms | 25ms | 15分 | 10分 | 50ms | 60分 | 50ms |
| メモリ | 128MB | 128MB | 10GB | 1.5GB | 512MB | 32GB | 128MB |
| KV ストア | Workers KV | Vercel KV | DynamoDB | Cosmos DB | Deno KV | Firestore | KV Store |
| SQL | D1 | Postgres | RDS/Aurora | SQL DB | - | Cloud SQL | - |
| グローバルエッジ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| WebSocket | ✅ | - | ✅ | ✅ | ✅ | ✅ | Fanout |

### 成功基準

- [ ] Cloudflare Workers デプロイ
- [ ] Vercel Edge デプロイ
- [ ] AWS Lambda デプロイ
- [ ] Azure Functions デプロイ
- [ ] Deno Deploy デプロイ
- [ ] Google Cloud Run デプロイ
- [ ] Fastly Compute@Edge デプロイ
- [ ] 統一 KV/DB API
- [ ] CLI デプロイツール
- [ ] マルチプラットフォーム同時デプロイ

---

## Phase 25: パフォーマンス & 最適化 (v0.23.0)

### 概要

パフォーマンスを最適化し、バンドルサイズを削減し、包括的なプロファイリングと最適化ツールで本番利用に向けてフレームワークを準備します。

### 計画機能

#### 25.1 パフォーマンス最適化
- Virtual DOM差分アルゴリズムの最適化
- メモリ割り当ての改善
- 遅延読み込みとコード分割
- 未使用コンポーネントのツリーシェイキング
- レンダリングバッチングとスケジューリング

#### 25.2 バンドルサイズ削減
- WASMバイナリの最適化
- プラットフォーム固有のデッドコード削除
- アセット圧縮と最適化
- コード圧縮と最小化

#### 25.3 本番機能
- エラーバウンダリコンポーネント
- クラッシュレポート統合
- アナリティクスフック
- A/Bテストサポート

#### 25.4 開発者体験
- CLI改善
- プロジェクトスキャフォールディングテンプレート
- IDEプラグイン（VSCode、IntelliJ）
- デバッグツール
- パフォーマンスプロファイラー

### 成功基準

- [ ] WASMコアバンドル 100KB未満（gzip）
- [ ] 1000コンポーネントで16ms未満のレンダリング時間
- [ ] 本番対応のエラーハンドリング
- [ ] 完全なCLIツールチェーン
- [ ] IDE統合

---

## Phase 26: ドキュメント充実 (v0.24.0)

### 概要

包括的なドキュメント、チュートリアル、学習リソースで、あらゆるスキルレベルの開発者がZylixを利用できるようにします。

### 計画機能

#### 26.1 APIドキュメント
- 全モジュールの完全なAPIリファレンス
- 各コンポーネントのインタラクティブな例
- TypeScript/JavaScript APIドキュメント
- プラットフォーム固有のAPIガイド

#### 26.2 チュートリアル & ガイド
- 各プラットフォームの入門チュートリアル
- ステップバイステップのプロジェクトチュートリアル
- ベストプラクティスガイド
- 他フレームワークからの移行ガイド

#### 26.3 サンプルアプリケーション
- 実用的なサンプルアプリケーション
- 業界別テンプレート（EC、ソーシャル、生産性）
- コードウォークスルーと解説

#### 26.4 インタラクティブ学習
- インタラクティブなプレイグラウンド/サンドボックス
- 即時プレビュー付きライブコード編集
- ビデオチュートリアルとスクリーンキャスト
- コミュニティ投稿の例

### 成功基準

- [ ] 完全なAPIドキュメントカバレッジ
- [ ] 10以上の包括的なチュートリアル
- [ ] インタラクティブプレイグラウンド稼働
- [ ] ビデオチュートリアルシリーズ
- [ ] コミュニティショーケースギャラリー

---

## Phase 27: 公式サンプルプロジェクト (v0.25.0)

### 概要

Zylixの全機能を活用した本格的なサンプルプロジェクト集。各サンプルはベストプラクティスを示し、学習教材および実用的なスターターテンプレートとして機能します。

### サンプルカテゴリ

#### 27.1 スターターテンプレート（4種類）

新規プロジェクト用のエントリーポイントテンプレート：

| テンプレート | 説明 | 機能 |
|------------|------|------|
| **Blank App** | 最小限のプロジェクト構造 | 基本セットアップ、ルーティングスキャフォールド |
| **Tab Navigation** | タブベースナビゲーションアプリ | TabBar、複数画面、状態保持 |
| **Drawer Navigation** | サイドメニューナビゲーションアプリ | ドロワー、ハンバーガーメニュー、ネストナビゲーション |
| **Dashboard Layout** | ビジネスダッシュボード構造 | ヘッダー、サイドバー、コンテンツエリア、レスポンシブ |

#### 27.2 機能ショーケース（7種類）

Zylix機能の完全なデモンストレーション：

**Component Gallery（コンポーネントギャラリー）**
- 40種類以上の全UIコンポーネントのインタラクティブな例
- 各コンポーネントのライブプロパティエディタ
- アクセシビリティテストパネル
- プラットフォーム別レンダリング比較

**Animation Studio（アニメーションスタジオ）**
- Lottieアニメーションプレーヤーとコントロール
- Live2Dキャラクターショーケース（表情・モーション）
- カスタムアニメーションタイムラインエディタ
- トランジションエフェクトギャラリー

**3D Viewer（3Dビューアー）**
- glTF/OBJ/FBXモデルローダー
- カメラコントロール（オービット、パン、ズーム）
- ライティングとマテリアルエディタ
- ポストプロセシングエフェクトデモ

**Game Arcade（ゲームアーケード）**
- 物理、スプライト、オーディオを示す3つのミニゲーム
- ゲーム状態管理パターン
- タッチ/キーボード入力処理
- リーダーボード連携

**AI Playground（AIプレイグラウンド）**
- Whisper音声認識デモ
- ストリーミング対応LLMチャットインターフェース
- VLM画像理解
- オンデバイス vs クラウド比較

**Device Lab（デバイスラボ）**
- カメラキャプチャとフィルター
- センサー可視化（加速度計、ジャイロスコープ、コンパス）
- GPS位置情報とジオフェンシング
- ハプティックフィードバックパターン
- プッシュ通知テスト

**Database Workshop（データベースワークショップ）**
- SQLite、PostgreSQL、Turso接続デモ
- 型安全なクエリによるCRUD操作
- オフラインファースト同期パターン
- マイグレーション例

#### 27.3 実用アプリケーション（8種類）

プロダクション対応アプリケーションテンプレート：

**TaskMaster** - 高度なタスク管理
```
機能:
├── カテゴリとタグ
├── 通知付き期日設定
├── 優先度とソート
├── 検索とフィルター
├── クラウド同期 (Firebase/Supabase)
├── オフラインサポート
├── ダーク/ライトテーマ
└── watchOSコンパニオン
```

**ShopDemo** - ECアプリケーション
```
機能:
├── 検索付き商品カタログ
├── カテゴリナビゲーション
├── ショッピングカート
├── アプリ内課金連携
├── 注文履歴
├── ユーザー認証
├── お気に入りリスト
└── 商品レビュー
```

**ChatSpace** - リアルタイムメッセージング
```
機能:
├── リアルタイムメッセージング (Supabase Realtime)
├── ユーザープレゼンス表示
├── ページネーション付きメッセージ履歴
├── ファイル添付（画像、ファイル）
├── プッシュ通知
├── 入力中インジケーター
├── 既読表示
└── グループ会話
```

**Analytics Pro** - ビジネスダッシュボード
```
機能:
├── リアルタイムデータ可視化
├── 複数のグラフタイプ（棒、折れ線、円、散布図）
├── ソート/フィルター付きデータテーブル
├── PDFレポートエクスポート
├── Excelデータエクスポート
├── 日付範囲セレクター
├── カスタムダッシュボード
└── ノードベースワークフローエディタ
```

**MediaBox** - メディアプレーヤー
```
機能:
├── コントロール付きオーディオ再生
├── 字幕付きビデオプレーヤー
├── プレイリスト管理
├── バックグラウンドオーディオ
├── メディアコントロール（ロック画面、通知）
├── イコライザー可視化
├── ストリーミングサポート
└── オフラインダウンロード
```

**NoteFlow** - メモ & ドキュメント
```
機能:
├── リッチテキスト編集
├── Markdownサポート
├── フォルダ整理
├── 全文検索
├── クラウド同期
├── PDFエクスポート
├── 画像埋め込み
└── タグとリンク
```

**FitTrack** - ヘルス & フィットネス
```
機能:
├── ワークアウト記録
├── ヘルスデータ可視化
├── 目標設定
├── 進捗グラフ
├── センサー連携（心拍数、歩数）
├── watchOSワークアウトアプリ
├── Apple Health / Google Fit連携
└── ソーシャル共有
```

**QuizMaster** - 教育クイズ
```
機能:
├── クイズ作成・編集
├── 複数の問題タイプ
├── タイマー付きクイズ
├── スコア記録
├── リーダーボード
├── 実績システム
├── オフラインモード
└── 分析とインサイト
```

#### 27.4 プラットフォーム固有ショーケース（5種類）

プラットフォーム専用機能のデモンストレーション：

**iOS Exclusive**
- ホームスクリーンウィジェット (WidgetKit)
- App Clips
- Siriショートカット連携
- SharePlayサポート
- 集中モードフィルター

**Android Exclusive**
- ホームスクリーンウィジェット
- タイル（クイック設定）
- ダイナミックショートカット
- 通知チャンネル
- ピクチャーインピクチャー

**Web PWA**
- Progressive Web App機能
- Service Workerキャッシュ
- プッシュ通知
- インストール可能性
- レスポンシブデザイン
- SEO最適化

**Desktop Native**
- ネイティブメニューバー連携
- コンテキストメニュー付きシステムトレイ
- ファイルシステムアクセス
- デスクトップからのドラッグ&ドロップ
- キーボードショートカット
- マルチウィンドウサポート

**watchOS Companion**
- ウォッチフェイス用コンプリケーション
- ワークアウトセッション管理
- ヘルスデータ同期
- Digital Crown操作
- 独立アプリ機能

#### 27.5 ゲームサンプル（4種類）

完全なゲーム実装：

**Platformer Adventure（プラットフォーマー）**
```
機能:
├── 物理ベースの移動
├── スプライトアニメーションシステム
├── タイルマップレベル
├── 敵AI
├── コレクティブルとパワーアップ
├── 効果音とBGM
├── セーブ/ロードシステム
└── 複数レベル
```

**Puzzle World（パズル）**
```
機能:
├── ドラッグ&ドロップ操作
├── マッチ3スタイルパズル
├── レベル進行
├── ヒントシステム
├── アニメーションとパーティクル
├── スコアシステム
└── デイリーチャレンジ
```

**Space Shooter（シューティング）**
```
機能:
├── 高速アクション
├── パーティクルエフェクト
├── パワーアップシステム
├── ボスバトル
├── ハイスコアリーダーボード
├── 複数の機体
└── 手続き生成レベル
```

**VTuber Demo（VTuberデモ）**
```
機能:
├── Live2Dキャラクターレンダリング
├── 表情コントロール
├── オーディオ連動リップシンク
├── モーショントラッキング（カメラ）
├── 背景置換
├── 録画サポート
└── 配信オーバーレイモード
```

#### 27.6 フルスタック連携（3種類）

エンドツーエンドアプリケーション例：

**Social Network（ソーシャルネットワーク）**
```
スタック: Zylix + Zylix Server + Supabase
├── ユーザー認証
├── プロフィール管理
├── 画像付き投稿作成
├── いいね・コメントシステム
├── フォロー/アンフォロー
├── リアルタイムフィード更新
├── 通知
└── ダイレクトメッセージ
```

**Project Board（プロジェクトボード）**
```
スタック: Zylix + Zylix Server + PostgreSQL
├── カンバンボードインターフェース
├── リアルタイムコラボレーション
├── カードのドラッグ&ドロップ
├── チーム管理
├── コメントと添付ファイル
├── アクティビティ履歴
├── ロールベース権限
└── メール通知
```

**API Server Demo（APIサーバーデモ）**
```
スタック: Zylix Server + エッジデプロイメント
├── RESTful API設計
├── 型安全なRPC
├── JWT認証
├── レート制限
├── Cloudflare Workersデプロイ
├── Vercel Edgeデプロイ
├── APIドキュメント (OpenAPI)
└── モニタリングダッシュボード
```

### 品質基準

全公式サンプルは以下の基準を満たす必要があります：

| 基準 | 要件 |
|------|------|
| **機能性** | 全ターゲットプラットフォームでエラーなく動作 |
| **デザイン** | Zylixデザインガイドラインに準拠、視覚的に洗練 |
| **コード品質** | ベストプラクティス、構造化、保守性 |
| **テスト** | ユニットテスト、E2Eテスト、ビジュアルリグレッションテスト |
| **ドキュメント** | README、コードコメント、チュートリアルウォークスルー |
| **アクセシビリティ** | WCAG 2.1 AA準拠 |
| **パフォーマンス** | プラットフォーム固有のパフォーマンス基準を満たす |
| **ライセンス** | MITライセンス、明確な帰属表示 |

### サンプルプロジェクト構造

```
samples/
├── templates/
│   ├── blank-app/
│   ├── tab-navigation/
│   ├── drawer-navigation/
│   └── dashboard-layout/
├── showcase/
│   ├── component-gallery/
│   ├── animation-studio/
│   ├── 3d-viewer/
│   ├── game-arcade/
│   ├── ai-playground/
│   ├── device-lab/
│   └── database-workshop/
├── apps/
│   ├── taskmaster/
│   ├── shop-demo/
│   ├── chat-space/
│   ├── analytics-pro/
│   ├── media-box/
│   ├── note-flow/
│   ├── fit-track/
│   └── quiz-master/
├── platform/
│   ├── ios-exclusive/
│   ├── android-exclusive/
│   ├── web-pwa/
│   ├── desktop-native/
│   └── watchos-companion/
├── games/
│   ├── platformer/
│   ├── puzzle-world/
│   ├── space-shooter/
│   └── vtuber-demo/
└── fullstack/
    ├── social-network/
    ├── project-board/
    └── api-server/
```

### リリース戦略

| 優先度 | サンプル | リリース |
|--------|---------|---------|
| **P0 (コア)** | Component Gallery, Animation Studio, TaskMaster, ChatSpace, Game Arcade, AI Playground, 3D Viewer, Device Lab, ShopDemo, Analytics Pro | v0.25.0 |
| **P1 (拡張)** | NoteFlow, MediaBox, FitTrack, Database Workshop, Platformer, VTuber Demo, Social Network, Project Board | v0.25.1 |
| **P2 (プラットフォーム)** | iOS Exclusive, Android Exclusive, Web PWA, Desktop Native, watchOS Companion | v0.25.2 |
| **テンプレート** | Blank App, Tab Navigation, Drawer Navigation, Dashboard Layout | 全バージョン |

### 成功基準

- [ ] 23種類以上のサンプルプロジェクトを完成・公開
- [ ] 全サンプルがターゲットプラットフォームで動作
- [ ] 各サンプルに包括的なドキュメント
- [ ] 全P0サンプルにステップバイステップチュートリアル
- [ ] 複雑なサンプルには動画ウォークスルー
- [ ] コミュニティフィードバックの反映
- [ ] 新しいZylix機能に合わせた定期更新
- [ ] ドキュメントサイトにサンプルプロジェクトギャラリー

---

## バージョン概要

### 完了したバージョン

#### v0.1.0 - 基盤構築 (2025-12-21)
- Virtual DOM実装
- 6プラットフォーム対応（iOS, Android, macOS, Windows, Linux, Web）
- 基本コンポーネントライブラリ（9種類）
- 言語バインディング用C ABIレイヤー

#### v0.5.0 - GitHub設定 (2025-12-21)
- コントリビューティングガイドライン
- セキュリティポリシー
- CI/CDワークフロー
- Issue/PRテンプレート

#### v0.6.0 - コア機能 (2025-12-21)
- ナビゲーションガード付きルーターモジュール
- 非同期ユーティリティ（Future/Promise）
- ホットリロード開発サーバー
- 5つのサンプルアプリケーション

#### v0.6.1 - セキュリティ修正 (2025-12-21)
- XSS防止ユーティリティ
- イベントデリゲーションパターン
- セキュアなID生成

#### v0.6.2 - プラットフォーム修正 (2025-12-21)
- 並行処理のバグ修正
- スレッドセーフティの改善
- メモリリーク防止

#### v0.7.0 - コンポーネントライブラリの拡充 (2025-12-22) ✅ 完了
- 40種類以上のコンポーネント
- フォーム、レイアウト、ナビゲーション、フィードバックコンポーネント
- プラットフォームネイティブ実装
- アクセシビリティサポート（ARIA、VoiceOver、TalkBack）
- ビジュアルリグレッションテスト

#### v0.8.1 - テスト基盤 & 言語バインディング (2025-12-23) ✅ 完了
- **watchOS サポート**:
  - Digital Crown 回転
  - サイドボタン操作
  - コンパニオンデバイス連携
- **言語バインディング**:
  - TypeScript: `@zylix/test` npm パッケージ
  - Python: `zylix-test` PyPI パッケージ
- **CI/CD**: GitHub Actions ワークフロー
- **E2E テスト**: クロスプラットフォームテストフレームワーク
- **サンプルデモ**: プラットフォーム別テストデモ

#### v0.9.0 - 組み込みAI (Zylix AI) (2025-12-24) ✅ 完了
- **組み込みLLM/VLMサポート**:
  - ローカルLLM統合（オンデバイス推論）
  - **埋め込みモデル**: テキストからベクトル変換
  - **言語モデル**: チャットと補完
  - **VLM**: 画像理解とOCR
  - **Whisper**: 音声からテキスト変換
  - **プラットフォームバックエンド**:
    - iOS: Core ML, Metal
    - llama.cpp: GGUF モデルサポート
    - miniaudio: オーディオデコード

#### v0.10.0 - デバイス機能 & ジェスチャー (2025-12-24) ✅ 完了
- **デバイス機能**:
  - GPS/位置情報、カメラ、センサー
  - 通知（ローカル/プッシュ）
  - オーディオ、ハプティクス、権限管理
  - バックグラウンド処理
- **ジェスチャー認識**:
  - タップ、長押し、パン、スワイプ
  - ピンチ、回転、ドラッグアンドドロップ
- **プラットフォーム実装**:
  - iOS: ZylixDevice.swift, ZylixGesture.swift
  - Android: ZylixDevice.kt, ZylixGesture.kt
  - Web: zylix-device.js, zylix-gesture.js

### 計画中のバージョン

#### v0.11.0 - アニメーションシステム ✅ 完了 (2025-12-24)
- Lottie ベクターアニメーションサポート
- Live2D Cubism SDK 統合
- アニメーション制御API
- タイムラインベースのシーケンス

#### v0.12.0 - 3Dグラフィックスエンジン ✅ 完了 (2025-12-24)
- Three.js/Babylon.js インスパイア3Dエンジン
- プラットフォームネイティブレンダリング（Metal、Vulkan、DirectX、WebGL/WebGPU）
- 3Dモデル読み込み（glTF、OBJ、FBX）
- ライティング、シャドウ、ポストプロセス

#### v0.13.0 - ゲーム開発プラットフォーム 🚧 進行中
- PIXI.js インスパイア2Dゲームエンジン
- Matter.js ベース物理エンジン
- 完全なオーディオシステム（効果音、BGM）
- Entity-Component-System アーキテクチャ

#### v0.14.0 - データベースサポート
- SQLite、MySQL、PostgreSQL、Turso/libSQL 接続
- 型安全なクエリビルダー
- コネクションプーリングとトランザクション
- クロスプラットフォームDB アクセス（WASM含む）

#### v0.15.0 - アプリ統合API
- アプリ内課金 (StoreKit 2, Play Billing)
- 広告抽象化 (バナー、インタースティシャル、リワード)
- KeyValueStore (永続ストレージ)
- アプリライフサイクルフック
- モーションフレームプロバイダー (カメラベースのモーショントラッキング)
- 低レイテンシオーディオクリッププレイヤー

#### v0.16.0 - 開発者ツール
- プロジェクトスキャフォールディングCLI
- ビルドオーケストレーションAPI
- テンプレートカタログシステム
- ファイルウォッチャーとホットリロード
- コンポーネントツリーエクスポート
- ライブプレビューブリッジ

#### v0.17.0 - ノードベースUI
- React Flow スタイルのノードコンポーネント
- ビジュアルワークフローエディタ
- パン/ズーム対応インタラクティブキャンバス
- カスタマイズ可能なノード/エッジタイプ

#### v0.18.0 - PDFサポート
- PDF生成と読み込み
- テキスト、画像、グラフィックス埋め込み
- PDF編集と結合
- フォームフィールドサポート

#### v0.19.0 - Excelサポート
- xlsxファイルの作成と読み込み
- セルの書式設定と数式
- グラフとデータ可視化
- 複数ワークシート対応

#### v0.20.0 - mBaaSサポート
- Firebase (Authentication, Firestore, Storage, FCM)
- Supabase (Auth, Database, Storage, Realtime)
- AWS Amplify (Auth, DataStore, Storage)
- 統一APIによるmBaaS抽象化レイヤー
- リアルタイム同期とオフライン対応

#### v0.21.0 - サーバーランタイム (Zylix Server)
- Hono.js インスパイア HTTP サーバー (Zig)
- 型安全な RPC（クライアント ↔ サーバー）
- ミドルウェアシステム
- サーバーサイドレンダリング

#### v0.22.0 - エッジアダプター
- Cloudflare Workers デプロイ
- Vercel Edge Functions
- AWS Lambda サポート
- Azure Functions サポート
- Deno Deploy サポート
- Google Cloud Run サポート
- Fastly Compute@Edge サポート
- 統一プラットフォーム API
- マルチプラットフォーム同時デプロイ

#### v0.23.0 - パフォーマンス & 最適化
- パフォーマンスプロファイリングと最適化
- バンドルサイズ削減
- メモリ使用量の最適化
- 遅延読み込みとコード分割

#### v0.24.0 - ドキュメント充実
- 完全なAPIドキュメント
- 包括的なチュートリアル
- 実用的なサンプルアプリケーション
- インタラクティブなプレイグラウンド
- ビデオチュートリアル

#### v0.25.0 - 公式サンプルプロジェクト
- 23種類以上の本格的なサンプルプロジェクト
- スターターテンプレート(4)、機能ショーケース(7)、実用アプリ(8)
- プラットフォーム固有サンプル(5)、ゲームサンプル(4)、フルスタック(3)
- 各サンプルに包括的なドキュメントとチュートリアル
- 全サンプルが品質基準を満たす（テスト、アクセシビリティ、パフォーマンス）

### 品質哲学

> **「量より質」** - 機能は少なくても、確実に動作することを保証します。

**基本原則**:
1. **ドキュメントは真実**: 全ての文書化された機能には動作するサンプルコードが必要
2. **テスト駆動開発**: 包括的なテストなしに機能をリリースしない
3. **CodeRabbitレビュー**: 品質保証のための定期的な自動コードレビュー
4. **段階的な進歩**: v0.9.0 → v0.10.0 → v0.11.0 と各ステップで安定性を検証
5. **ユーザーファーストのドキュメント**: 公式ドキュメントは「初心者への最高の道しるべ」

---

## コントリビュート

Zylix開発への貢献ガイドラインは[CONTRIBUTING.md](../CONTRIBUTING.md)を参照してください。

## 参考資料

- [現在のPLAN.md](./PLAN.md) - 元のプロジェクト計画
- [ARCHITECTURE.md](./ARCHITECTURE.md) - システムアーキテクチャ
- [ABI.md](./ABI.md) - C ABI仕様
- [ROADMAP.md](./ROADMAP.md) - 英語版ロードマップ
