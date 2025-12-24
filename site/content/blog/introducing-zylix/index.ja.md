---
title: "Zylix 発表: Zig で構築されたクロスプラットフォーム UI フレームワーク"
date: 2024-12-22
authors:
  - name: Zylix Team
summary: "Zylix v0.1.0 を発表します。Zig で構築された高性能クロスプラットフォーム UI フレームワークです。UI ロジックを一度書くだけで、Web、iOS、Android、macOS、Linux、Windows に展開できます。"
tags:
  - announcement
  - release
---

**Zylix** の最初のパブリックリリースを発表できることを嬉しく思います。Zylix は、完全に Zig で構築されたクロスプラットフォーム UI フレームワークです。開発者は UI ロジックを一度書くだけで、Web/WASM、iOS、watchOS、Android、macOS、Linux、Windows の7つのプラットフォームにデプロイできます。

## なぜ Zylix なのか？

現代のアプリ開発では、各プラットフォームごとに別々のコードベースを維持する必要があることがよくあります。Zylix は異なるアプローチを取ります：単一の Zig コアが各ターゲットプラットフォームのネイティブコードにコンパイルされ、それぞれのネイティブ UI フレームワークを活用します。

### 主な特徴

- **Virtual DOM エンジン**: 効率的な差分アルゴリズムで最小限の UI 更新を実現
- **型安全な状態管理**: コンパイル時型チェックによる集中型状態管理
- **ネイティブプラットフォーム統合**: SwiftUI、Jetpack Compose、GTK4、WinUI 3、WebAssembly
- **ガベージコレクションなし**: アリーナアロケーションによる予測可能なパフォーマンス
- **軽量**: コアライブラリはわずか 50-150KB

## 現在の状態

Zylix v0.1.0 では以下が利用可能です：

- 9つの基本 UI コンポーネント（Container、Text、Button、Image、Input、List、ScrollView、Link、Spacer）
- CSS ユーティリティシステム（TailwindCSS 風の構文）
- Flexbox レイアウトエンジン
- イベント処理システム
- Web/WASM プラットフォームはベータ版、その他のプラットフォームはアルファ版

## 試してみる

[ライブデモ](/ja/demo)で Zylix の動作を確認するか、[ドキュメント](/ja/docs/getting-started)から始めてください。

```bash
# リポジトリをクローン
git clone https://github.com/kotsutsumi/zylix.git
cd zylix

# コアライブラリをビルド
cd core && zig build

# Web デモを実行
zig build wasm -Doptimize=ReleaseSmall
cd ../platforms/web
python3 -m http.server 8080
```

## 今後の予定

[ロードマップ](/ja/docs/roadmap)で計画されている機能：

- **v0.2.0**: 拡張コンポーネントライブラリ（30以上のコンポーネント）
- **v0.3.0**: クロスプラットフォームルーティングシステム
- **v0.4.0**: 非同期処理（HTTP、ファイル I/O）
- **v0.5.0**: 開発時の Hot Reload
- **v0.6.0**: サンプルアプリケーション

## 参加する

Zylix は Apache License 2.0 の下でオープンソースとして公開されています。あらゆるスキルレベルの開発者からのコントリビューションを歓迎します。

- [GitHub リポジトリ](https://github.com/kotsutsumi/zylix)
- [イシュートラッカー](https://github.com/kotsutsumi/zylix/issues)
- [ディスカッション](https://github.com/kotsutsumi/zylix/discussions)

Zylix に興味を持っていただきありがとうございます。クロスプラットフォーム開発の未来を一緒に構築できることを楽しみにしています。
