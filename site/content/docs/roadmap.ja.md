---
title: ロードマップ
weight: 5
prev: platforms
---

このページでは、Zylixの開発ロードマップを説明します。各フェーズでは、パフォーマンス、シンプルさ、ネイティブプラットフォーム統合というフレームワークの核心原則を維持しながら、新しい機能を導入します。

> 完全な詳細ロードマップは[ROADMAP.ja.md](https://github.com/kotsutsumi/zylix/blob/main/docs/ROADMAP.ja.md)をご覧ください。

## 現在の状況

**バージョン 0.8.1** が現在のリリースです：

- 効率的な差分計算を持つVirtual DOMエンジン
- 型安全な状態管理
- 40種類以上のUIコンポーネント（フォーム、レイアウト、ナビゲーション、フィードバック、データ表示）
- CSSユーティリティシステム（TailwindCSS風）
- Flexboxレイアウトエンジン
- 6プラットフォーム対応（Web、iOS、Android、macOS、Linux、Windows）
- 7番目のプラットフォーム：watchOS対応
- C ABI (v2) とWASMバインディング
- 優先度システム付きイベントキュー
- 効率的な更新のためのState Diff API
- TypeScriptとPython言語バインディング
- E2Eテストフレームワーク
- CI/CDパイプライン

## ロードマップ概要

| バージョン | 主要機能 | 状態 |
|-----------|---------|------|
| v0.1.0 - v0.6.0 | 基盤構築 & コア機能 | 完了 |
| v0.7.0 | コンポーネントライブラリ（40種類以上） | 完了 |
| v0.8.1 | テスト、watchOS、言語バインディング | 現在 |
| v0.9.0 | 組み込みAI (Zylix AI) | 計画中 |
| v0.10.0 | デバイス機能 & ジェスチャー | 計画中 |
| v0.11.0 | パフォーマンス & 最適化 | 計画中 |
| v0.12.0 | ドキュメント充実 | 計画中 |
| v0.13.0 | アニメーション（Lottie、Live2D） | 計画中 |
| v0.14.0 | 3Dグラフィックス | 計画中 |
| v0.15.0 | ゲーム開発 | 計画中 |
| v0.16.0 - v0.21.0 | ノードUI、PDF、Excel、DB、サーバー、エッジ | 計画中 |

## 完了したマイルストーン

### v0.8.1 - テスト & 言語バインディング

- watchOSプラットフォーム対応
- TypeScriptバインディング（`@zylix/test` npmパッケージ）
- Pythonバインディング（`zylix-test` PyPIパッケージ）
- 全プラットフォーム用E2Eテストフレームワーク
- CI/CDワークフロー（GitHub Actions）

### v0.7.0 - コンポーネントライブラリ

5カテゴリで40種類以上のコンポーネント：

- **フォーム**: select、checkbox、radio、textarea、toggle、slider、form
- **レイアウト**: vstack、hstack、zstack、grid、scroll_view、spacer、divider、card
- **ナビゲーション**: nav_bar、tab_bar
- **フィードバック**: alert、toast、modal、progress、spinner
- **データ表示**: icon、avatar、tag、badge、accordion

### v0.6.x - コア機能

- ナビゲーションガードとディープリンク付きルーター
- 非同期ユーティリティ（Future/Promiseパターン）
- Hot Reload開発サーバー
- サンプルアプリケーション
- プラットフォームデモ（iOS、Android）

## 今後の機能

### v0.9.0 - Zylix AI

AI搭載の開発アシスタント：

- 自然言語からコンポーネント生成
- インテリジェントなデバッグ支援
- PRレビュー統合
- ドキュメント自動生成

### v0.10.0 - デバイス機能

- GPS/位置情報サービス
- カメラアクセス
- プッシュ通知（APNs、FCM）
- 高度なジェスチャー（ドラッグ&ドロップ、ピンチ、スワイプ）

### v0.13.0以降 - 高度な機能

- **アニメーション**: Lottie、Live2D統合
- **3Dグラフィックス**: Three.js風エンジン
- **ゲーム開発**: 2Dエンジン、物理、オーディオ
- **ドキュメント対応**: PDF、Excel操作
- **サーバーランタイム**: フルスタックZigアプリケーション
- **エッジ展開**: Cloudflare、Vercel、AWSアダプター

## コントリビュート

コントリビュートを歓迎します！詳細は[コントリビュートガイド](https://github.com/kotsutsumi/zylix/blob/main/CONTRIBUTING.md)をご覧ください。

## 詳細ドキュメント

- [完全なロードマップ（英語）](https://github.com/kotsutsumi/zylix/blob/main/docs/ROADMAP.md)
- [完全なロードマップ（日本語）](https://github.com/kotsutsumi/zylix/blob/main/docs/ROADMAP.ja.md)
- [互換性リファレンス](https://github.com/kotsutsumi/zylix/blob/main/docs/COMPATIBILITY.md)
