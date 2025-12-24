# Zylix 開発メモ (Work in Progress)

## 現在のステータス: 2025-12-24

### 完了済み
- [x] Zig コアライブラリ (drivers, selectors, elements, etc.)
- [x] CLI ツール (`zylix-test` コマンド)
- [x] 統合テスト基盤 (Mock HTTP Server + プラットフォーム別テスト)
- [x] ビルドシステム (クロスコンパイル対応)
- [x] **watchOS 対応** (2025-12-23 完了)
- [x] **CI/CD - GitHub Actions 自動化** (2025-12-23 完了)
- [x] **E2E テスト** (2025-12-23 完了)
- [x] **ドキュメント - API リファレンス整備** (2025-12-23 完了)
- [x] **サンプル - 各プラットフォーム向けデモ** (2025-12-23 完了)
- [x] **言語バインディング - TypeScript/Python** (2025-12-23 完了)
- [x] **v0.15.0 App Integration APIs** (2025-12-23 完了)
- [x] **v0.16.0 Developer Tooling APIs** (2025-12-23 完了)
- [x] **v0.17.0 Node-based UI Module (NodeFlow)** (2025-12-24 完了)
- [x] **v0.18.0 PDF Support** (2025-12-24 完了)
- [x] **メモリリーク修正 (integration/ads.zig, keyvalue.zig)** (2025-12-24 完了)

### 統合テスト構成
```
core/src/test/integration/
├── integration_tests.zig      # メインエントリーポイント
├── mock_server.zig            # Mock HTTP Server (Zig 0.15対応済み)
├── web_integration_test.zig
├── ios_integration_test.zig
├── watchos_integration_test.zig  # NEW: watchOS テスト
├── android_integration_test.zig
└── desktop_integration_test.zig
```

### ビルドコマンド
```bash
cd core
zig build test              # ユニットテスト
zig build test-integration  # 統合テスト
zig build test-all          # 全テスト
```

---

## 完了タスク: watchOS 対応 ✅ (2025-12-23)

### 実装内容

#### 1. Zig ドライバー拡張 (`core/src/test/ios_driver.zig`)
- `SimulatorType` に Apple Watch デバイス追加
  - `.apple_watch_series_9_41mm`
  - `.apple_watch_series_9_45mm`
  - `.apple_watch_series_10_42mm`
  - `.apple_watch_series_10_46mm`
  - `.apple_watch_ultra_2`
  - `.apple_watch_se_40mm`
  - `.apple_watch_se_44mm`
- `IOSDriverConfig` に watchOS 固有設定追加
  - `is_watchos: bool`
  - `watchos_version: []const u8`
  - `companion_device_udid: ?[]const u8`
- ヘルパー関数追加: `isWatchOS()`, `platformVersion()`, `platformName()`
- watchOS 固有アクション追加:
  - `rotateDigitalCrown()` - Digital Crown 回転
  - `pressSideButton()` - サイドボタン押下
  - `doublePresssSideButton()` - サイドボタンダブルプレス (Apple Pay等)
  - `getCompanionDeviceInfo()` - コンパニオンデバイス情報取得

#### 2. Swift ブリッジサーバー拡張 (`platforms/ios/zylix-test/`)
- `Session` クラスに `isWatchOS`, `companionDeviceUDID` 追加
- WDA コマンド追加:
  - `/wda/digitalCrown/rotate` - Digital Crown 回転
  - `/wda/sideButton/press` - サイドボタン押下
  - `/wda/sideButton/doublePress` - サイドボタンダブルプレス
  - `/wda/companion/info` - コンパニオンデバイス情報

#### 3. 統合テスト (`core/src/test/integration/watchos_integration_test.zig`)
- watchOS セッション作成テスト
- Digital Crown テスト
- サイドボタンテスト
- コンパニオンデバイスペアリングテスト

#### 4. 参考コマンド
```bash
# watchOS シミュレータ一覧
xcrun simctl list devices | grep -i watch

# ペアリング
xcrun simctl pair <watch-udid> <phone-udid>

# watchOS アプリインストール
xcrun simctl install <watch-udid> /path/to/app.app
```

---

## 完了タスク: CI/CD - GitHub Actions ✅ (2025-12-23)

### 実装内容

#### CI ワークフロー (`.github/workflows/ci.yml`)
- **Core Build**: Zig 0.15.2 (Ubuntu, macOS, Windows)
  - Unit tests, Integration tests, Release build
- **iOS/watchOS Build**: Swift (macOS)
  - Bridge server build, Swift tests, Xcode build
- **macOS Build**: Swift bridge server
- **Android Build**: Kotlin/Gradle (JDK 17)
  - Library build, Test server build, Unit tests, Lint
- **Windows Build**: .NET 8.0
- **Linux Lint**: Python (flake8, mypy)
- **Web Tests**: Node.js 20 (syntax check, npm test)
- **Documentation Build**: Hugo (extended)
- **CodeRabbit Review**: PR 時のみ

#### Release ワークフロー (`.github/workflows/release.yml`)
- タグプッシュ時に自動リリース作成
- マルチプラットフォーム Core ビルド

---

## 完了タスク: E2E テスト ✅ (2025-12-23)

### 実装内容

#### E2E テストフレームワーク (`core/src/test/e2e/`)
- **e2e_tests.zig**: メインエントリーポイント、共通ユーティリティ
  - サーバー可用性チェック
  - HTTP リクエスト送信
  - JSON レスポンスパース
  - テストランナー
- **web_e2e_test.zig**: Web (ChromeDriver) テスト
  - セッション作成/削除
  - ナビゲーション
  - 要素検索
  - スクリーンショット
- **ios_e2e_test.zig**: iOS/watchOS (WebDriverAgent) テスト
  - セッションライフサイクル
  - 要素検索 (accessibility ID)
  - Digital Crown/Side Button
- **android_e2e_test.zig**: Android (Appium/UIAutomator2) テスト
  - セッション管理
  - UI Automator セレクター
  - スクリーンショット
- **desktop_e2e_test.zig**: macOS/Windows/Linux テスト
  - プラットフォーム別アクセシビリティブリッジ

#### ビルドコマンド
```bash
cd core
zig build test-e2e        # E2E テスト (ブリッジサーバー必要)
zig build test-everything # 全テスト (unit + integration + e2e)
```

---

## 完了タスク: サンプル - プラットフォームデモ ✅ (2025-12-23)

### 実装内容

#### テストデモスイート (`samples/test-demos/`)
```
samples/test-demos/
├── README.md                    # 概要と使用方法
├── web/                         # Web (Playwright) テスト
│   ├── README.md
│   ├── package.json
│   ├── playwright.config.js
│   └── tests/example.spec.js
├── ios/                         # iOS (WebDriverAgent) テスト
│   ├── README.md
│   ├── Package.swift
│   ├── Sources/ZylixTestClient.swift
│   └── Tests/IOSTestDemoTests.swift
├── watchos/                     # watchOS (WDA + Digital Crown) テスト
│   ├── README.md
│   ├── Package.swift
│   ├── Sources/ZylixWatchTestClient.swift
│   └── Tests/WatchOSTestDemoTests.swift
├── android/                     # Android (Appium/UIAutomator2) テスト
│   ├── README.md
│   ├── build.gradle.kts
│   ├── src/main/kotlin/ZylixAndroidTestClient.kt
│   └── src/test/kotlin/AndroidTestDemoTests.kt
└── macos/                       # macOS (Accessibility Bridge) テスト
    ├── README.md
    ├── Package.swift
    ├── Sources/ZylixMacTestClient.swift
    └── Tests/MacOSTestDemoTests.swift
```

#### 各プラットフォームのデモ内容
- **Web**: セッション管理、要素検索、ナビゲーション、スクリーンショット
- **iOS**: タップ、スワイプ、アクセシビリティID検索、ロングプレス
- **watchOS**: Digital Crown 回転、サイドボタン、コンパニオンデバイス
- **Android**: UIAutomator セレクター、バック/ホームボタン、スワイプ
- **macOS**: ウィンドウ管理、メニューバー、キーボードショートカット

---

## 完了タスク: 言語バインディング ✅ (2025-12-23)

### 実装内容

#### TypeScript バインディング (`bindings/typescript/`)
- **パッケージ名**: `@zylix/test`
- **npm バージョン**: 0.8.0
- **構成**:
  ```
  bindings/typescript/
  ├── package.json          # npm 設定
  ├── tsconfig.json         # TypeScript 設定
  ├── tsup.config.ts        # バンドル設定 (ESM + CJS)
  ├── README.md             # ドキュメント
  └── src/
      ├── index.ts          # エントリーポイント
      ├── types.ts          # 型定義
      ├── client.ts         # HTTP クライアント
      ├── selectors.ts      # セレクタービルダー
      ├── element.ts        # 要素実装
      └── drivers/
          ├── index.ts
          ├── base.ts       # ベースドライバー
          ├── web.ts        # Web (ChromeDriver)
          ├── ios.ts        # iOS (WebDriverAgent)
          ├── watchos.ts    # watchOS (WDA)
          ├── android.ts    # Android (Appium)
          └── macos.ts      # macOS (Accessibility Bridge)
  ```
- **機能**:
  - 全プラットフォームドライバー (Web, iOS, watchOS, Android, macOS)
  - 10種類のセレクター (testId, accessibilityId, XPath, CSS, etc.)
  - 要素操作 (tap, type, swipe, etc.)
  - エラーハンドリング (ZylixError, ElementNotFoundError, etc.)
  - TypeScript 完全型サポート

#### Python バインディング (`bindings/python/`)
- **パッケージ名**: `zylix-test`
- **PyPI バージョン**: 0.8.0
- **Python 対応**: 3.10+
- **構成**:
  ```
  bindings/python/
  ├── pyproject.toml        # PEP 621 設定
  ├── README.md             # ドキュメント
  └── src/zylix_test/
      ├── __init__.py       # エントリーポイント
      ├── py.typed          # PEP 561 型マーカー
      ├── types.py          # 型定義
      ├── client.py         # HTTP クライアント (httpx)
      ├── selectors.py      # セレクタービルダー
      ├── element.py        # 要素実装
      └── drivers/
          ├── __init__.py
          ├── base.py       # ベースドライバー
          ├── web.py        # Web (ChromeDriver)
          ├── ios.py        # iOS (WebDriverAgent)
          ├── watchos.py    # watchOS (WDA)
          ├── android.py    # Android (Appium)
          └── macos.py      # macOS (Accessibility Bridge)
  ```
- **機能**:
  - async/await 対応
  - 全プラットフォームドライバー
  - 10種類のセレクター
  - 完全型アノテーション (mypy strict 対応)
  - ruff/mypy/pytest 設定済み

#### インストールコマンド
```bash
# TypeScript
npm install @zylix/test
yarn add @zylix/test
pnpm add @zylix/test

# Python
pip install zylix-test
uv add zylix-test
poetry add zylix-test
```

---

## 次のタスク候補

🚀 **v0.18.0 リリース準備中**

現在のタスク:
- [ ] パフォーマンスベンチマーク
- [ ] v0.18.0 リリース (CHANGELOG更新、タグ作成)

---

## 将来のタスク候補

| 優先度 | タスク | 説明 | 状態 |
|--------|--------|------|------|
| ~~High~~ | ~~E2Eテスト~~ | ~~実際のブリッジサーバーとの結合テスト~~ | ✅ 完了 |
| ~~High~~ | ~~CI/CD~~ | ~~GitHub Actions 自動化~~ | ✅ 完了 |
| ~~Medium~~ | ~~ドキュメント~~ | ~~API リファレンス整備~~ | ✅ 完了 |
| ~~Medium~~ | ~~サンプル~~ | ~~各プラットフォーム向けデモ~~ | ✅ 完了 |
| ~~Low~~ | ~~言語バインディング~~ | ~~TypeScript/Python ラッパー~~ | ✅ 完了 |
| ~~Medium~~ | ~~v0.15.0 App Integration~~ | ~~広告、課金、Analytics、KVS~~ | ✅ 完了 |
| ~~Medium~~ | ~~v0.16.0 Developer Tooling~~ | ~~Console、DevTools、Profiler~~ | ✅ 完了 |
| ~~Medium~~ | ~~v0.17.0 NodeFlow~~ | ~~Node-based UI Module~~ | ✅ 完了 |
| ~~Medium~~ | ~~v0.18.0 PDF Support~~ | ~~PDF Parser、Writer、Font~~ | ✅ 完了 |
| High | パフォーマンス | ベンチマーク、最適化 | 🔄 作業中 |
| High | v0.18.0 リリース | CHANGELOG、タグ作成 | 🔜 次期 |

---

## 技術メモ

### Zig 0.15 対応
- `std.time.sleep` → `std.Thread.sleep`
- `std.ArrayList(T).init(allocator)` → `std.ArrayListUnmanaged(T)` 推奨
- `std.mem.split` → `std.mem.splitSequence`

### テストポート割り当て
| Platform | Test Port | Production Port |
|----------|-----------|-----------------|
| Web      | 19515     | 9515            |
| iOS      | 18100     | 8100            |
| watchOS  | 18101     | 8100            |
| Android  | 16790     | 6790            |
| macOS    | 18200     | 8200            |
| Linux    | 18300     | 8300            |

### 主要ファイル
- `core/build.zig` - ビルド設定
- `core/src/main.zig` - ライブラリエントリー
- `core/src/test/driver.zig` - ドライバーインターフェース (Platform enum含む)
- `core/src/test/ios_driver.zig` - iOS/watchOS ドライバー
- `core/src/test/integration/watchos_integration_test.zig` - watchOS 統合テスト
- `platforms/ios/zylix-test/Sources/ZylixTest/ZylixTestServer.swift` - Swift ブリッジサーバー

---

## 復帰時のチェックリスト

1. [ ] `zig build test-all` が通ることを確認
2. [ ] このメモを読んで状況を把握
3. [x] ~~watchOS 対応から着手~~ → 完了 (2025-12-23)
4. [ ] 次のタスクを選択して着手
