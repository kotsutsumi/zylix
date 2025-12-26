---
title: ロードマップ
weight: 5
prev: platforms
summary: Zylix の開発ロードマップ。パフォーマンス、シンプルさ、ネイティブプラットフォーム統合を維持しながら新機能を導入します。
---

このページでは、Zylixの開発ロードマップを説明します。各フェーズでは、パフォーマンス、シンプルさ、ネイティブプラットフォーム統合というフレームワークの核心原則を維持しながら、新しい機能を導入します。

> 完全な詳細ロードマップは[ROADMAP.ja.md](https://github.com/kotsutsumi/zylix/blob/main/docs/ROADMAP.ja.md)をご覧ください。

**最終同期日:** 2025-12-26

## 現在の状況

**バージョン 0.22.0** が現在の安定リリースです：

- 完全な IDE 統合向け P2 ツーリング API
- Component Tree Export、Live Preview Bridge、Hot Reload API
- Language Server Protocol (LSP) と Debug Adapter Protocol (DAP) サポート
- 外部ツーリング向け完全な C ABI エクスポート

## ロードマップ概要

| バージョン | 主要機能 | 状態 |
|-----------|---------|------|
| v0.1.0 - v0.6.3 | 基盤構築、ルーティング、非同期、Hot Reload、サンプル | 完了 |
| v0.7.0 | コンポーネントライブラリ（40種類以上） | 完了 |
| v0.8.1 | テスト、watchOS、言語バインディング | 完了 |
| v0.9.0 - v0.10.0 | AI、デバイスAPI、アニメーション、3D、ゲーム | 完了 |
| v0.18.0 - v0.19.3 | ツーリング API、C ABI、Zig 0.15 互換性 | 完了 |
| v0.20.0 | P0 ツーリング API、27個のサンプルリポジトリ | 完了 |
| v0.21.0 | M5Stack CoreS3 組み込みプラットフォームサポート | 完了 |
| v0.22.0 | P2 ツーリング API（IDE 統合） | 現在 |
| v0.23.0 | テストフレームワーク（XCUITest、Espresso） | 次期 |

## 次期リリース: v0.23.0 - テストフレームワーク

ネイティブテストフレームワーク統合：

- **iOS XCUITest 統合**: iOS アプリ向けネイティブ E2E テスト（Issue #64）
- **Android Espresso 統合**: Android アプリ向けネイティブ E2E テスト（Issue #65）
- **クロスプラットフォームテストオーケストレーション**: CI/CD パイプラインサポート（Issue #66）

## 最近のリリース

### v0.22.0 - P2 ツーリング API (2025-12-26)

完全な IDE 統合ツーリング：

- **Component Tree Export API**: UI 階層アクセス用 C ABI エクスポート（Issue #56）
- **Live Preview Bridge API**: プレビューセッション管理用 C ABI エクスポート（Issue #57）
- **Hot Reload API**: ライブアップデート対応開発プレビュー（Issue #61）
- **LSP 統合**: Language Server Protocol サポート（Issue #62）
- **DAP 統合**: Debug Adapter Protocol サポート（Issue #63）
- 外部ツーリング利用向け完全な C ABI エクスポート
- すべてのツーリング API の包括的なユニットテスト

### v0.21.0 - M5Stack 組み込みプラットフォーム (2025-12-26)

- **ディスプレイ**: ILI9342C ドライバー（SPI、320x240、RGB565）
- **タッチ**: FT6336U 静電容量式タッチコントローラー
- **電源管理**: AXP2101 PMIC、AW9523B I/O エキスパンダー
- **統合**: 組み込みディスプレイ向け Virtual DOM レンダラー
- **サンプル**: Hello World、Counter、Touch Demo

詳細は [M5Stack 実装計画](https://github.com/kotsutsumi/zylix/blob/main/docs/M5STACK_IMPLEMENTATION_PLAN.md) をご覧ください。

### v0.20.0 - ツーリング API & サンプルリポジトリ (2025-12-26)

- **コンポーネントレジストリ API** - IDE ツール用コンポーネント検出
- **UI レイアウトシリアライゼーション** - .zy.ui ファイルフォーマット対応
- **コンポーネントインスタンス化** - Live Preview コンポーネントファクトリ
- **27個のサンプルリポジトリ** - スターターテンプレート、機能ショーケース、実用アプリ、ゲーム
- スレッドセーフティとセキュリティ修正（CodeRabbit レビュー）

### v0.19.3 - Zig 0.15 互換性 (2025-12-26)

- tooling/artifacts.zig の Zig 0.15 向け ArrayList API 修正
- `std.ArrayListUnmanaged` パターンへの移行

### v0.19.2 - CI 修正 (2025-12-26)

- AI 依存関係（llama.cpp、whisper.cpp）をオプション化
- コンテナディレクトリ用 Web プラットフォームテスト除外を修正

### v0.19.1 - 統合プラットフォームバインディング (2025-12-26)

- iOS: モーショントラッキング、オーディオ、IAP、広告、キーバリューストア、アプリライフサイクル
- Android: CameraX、SoundPool、Play Billing、SharedPreferences、ProcessLifecycle
- ツーリング C ABI エクスポートとクロスプラットフォーム互換性改善

## 過去のマイルストーン

### v0.10.0 - パフォーマンス & 最適化

- プロファイリング、差分キャッシュ、メモリプール
- レンダリングのバッチ処理とスケジューリング
- 最適化の設定/メトリクス

### v0.9.0 - AI & デバイス機能

- AI モジュール統合（Whisper、Core ML）
- デバイス API 改善
- アニメーションと 3D 強化

## 次のリリース

**v0.23.0** では、iOS XCUITest、Android Espresso、クロスプラットフォームテストオーケストレーションなど、ネイティブテストフレームワーク統合を導入し、包括的な E2E テストサポートを提供します。

## コントリビュート

コントリビュートを歓迎します！詳細は[コントリビュートガイド](https://github.com/kotsutsumi/zylix/blob/main/CONTRIBUTING.md)をご覧ください。

## 詳細ドキュメント

- [完全なロードマップ（英語）](https://github.com/kotsutsumi/zylix/blob/main/docs/ROADMAP.md)
- [完全なロードマップ（日本語）](https://github.com/kotsutsumi/zylix/blob/main/docs/ROADMAP.ja.md)
- [互換性リファレンス](https://github.com/kotsutsumi/zylix/blob/main/docs/COMPATIBILITY.md)
