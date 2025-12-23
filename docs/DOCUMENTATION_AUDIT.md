# Zylix Framework ドキュメント監査レポート

## 1. エグゼクティブサマリー

- **全体評価**: 3/5（情報量は多いが、バージョン/内容不整合が目立つ）
- **主要な強み**
  - ルート/内部/サイトで網羅的なドキュメント構成があり、参照先が多い
  - `docs/ROADMAP.md` と `docs/ROADMAP.ja.md` は成功基準まで詳細に記述されている
  - `site/content/` は EN/JA ペアが揃っており、`site/i18n/` もキー差分なし
- **主要な改善点**
  - バージョン情報（Zig/プロジェクト/ABI/API）を全ドキュメントで統一
  - ルート/サイト/設計ドキュメント間のロードマップ整合性を回復
  - 実装と食い違う技術仕様（ABI/API、データフロー）を更新

---

## 2. 詳細レポート

### A. 一貫性チェック

**現状評価**
- 主要ドキュメント群は揃っているが、バージョン・ロードマップ・ステータスの整合性が崩れている。

**発見した問題点**
- Zig バージョンの不一致:
  - `README.md` は 0.15.0+、`CONTRIBUTING.md` は 0.11.0+、`site/content/docs/getting-started.md` は 0.13.0+、`CHANGELOG.md` は CI で Zig 0.15.2 を使用。
- Test Framework のバージョン不一致:
  - `docs/API_REFERENCE.md` と `docs/ZYLIX_TEST_FRAMEWORK.md` が v0.8.0 表記だが、`CHANGELOG.md` と `docs/ROADMAP.md` は v0.8.1 を最新とする。
- ロードマップの整合性崩れ:
  - `docs/ROADMAP.md` の「Planned Versions」セクションは v0.8.0 を計画扱いにし、v0.9.0〜v0.11.0 の内容がテーブルとずれている。
  - `docs/ROADMAP.ja.md` と内容が一致せず、翻訳差分が発生。
- EN/JA での内容差分:
  - `docs/ROADMAP.md` の v0.6.3 は "Platform Demos (iOS, Android)" だが、`docs/ROADMAP.ja.md` では「npm パッケージ同期」になっている。
  - 日付も 2025-12-22 / 2025-12-21 で不一致。
- ルートとサイトのロードマップの不一致:
  - `site/content/docs/roadmap.md` / `.ja.md` は v0.1.0 が現在で、v0.2.0〜v0.6.0 を将来計画として記載。
  - ルート `docs/ROADMAP.md` は v0.8.1 を現在としている。
- プラットフォームの成熟度表現の不一致:
  - `README.md` は Web/WASM を “Production Ready”、iOS/macOS を “Working” としている。
  - `site/content/docs/_index.md` は Web を Beta、他を Alpha としている。

**具体的な改善提案**
- Zig バージョンは 1 箇所を「正」とし、他はそこを参照する形に統一（例: `docs/COMPATIBILITY.md` にまとめ、他はリンク）。
- `docs/ROADMAP.md` の「Planned Versions」をテーブルと一致させ、JA 版と差分が出ないよう同期。
- `site/content/docs/roadmap.*` を `docs/ROADMAP.*` の要約に刷新し、現行バージョンを一致させる。
- プラットフォーム成熟度の表現基準を定義し、README/サイトを統一。

---

### B. 完全性チェック

**現状評価**
- ルートのロードマップは v0.21.0 まで記載されているが、設計ドキュメントやサイト側の更新が追従していない。

**発見した問題点**
- 設計ドキュメントの欠落:
  - `docs/designs/` に v0.16.0〜v0.21.0 が存在しない。
- ロードマップの Version Summary が欠落/ずれ:
  - `docs/ROADMAP.md` の「Planned Versions」に v0.12.0 が登場せず、v0.9.0〜v0.11.0 の内容がテーブルと一致しない。
- Getting Started のサンプル導線不足:
  - `README.md` の `samples/` 参照に対し、`site/content/docs/getting-started.md` は実際のサンプル導線が弱い。

**具体的な改善提案**
- v0.16.0〜v0.21.0 の設計ドキュメントを最小スコープで作成（目標・API・依存関係・リスクだけでも可）。
- `docs/ROADMAP.md` の Version Summary をテーブルと一致させ、欠落版を補完。
- Getting Started に `samples/` へのリンクと最短手順を追加。

---

### C. 技術的正確性

**現状評価**
- 仕様書が充実している一方、実装に追いついていない箇所が複数ある。

**発見した問題点**
- ABI 仕様の不一致:
  - `docs/ABI.md` は `ZYLIX_ABI_VERSION 1` だが、`core/src/abi.zig` は `ABI_VERSION = 2`。
  - `core/src/abi.zig` に存在する `zylix_queue_event` / `zylix_process_events` / `zylix_get_diff` などが `docs/ABI.md` に記載されていない。
- データフローの記述不整合:
  - `site/content/docs/getting-started.md` は「patches を返す」前提で説明しているが、実装は state/diff 取得が中心。
- Test Framework の進捗不一致:
  - `docs/ZYLIX_TEST_FRAMEWORK.md` は「設計フェーズ」、`CHANGELOG.md` は v0.8.1 で E2E 実装済み。

**具体的な改善提案**
- ABI 仕様書は `core/src/abi.zig` を唯一の真として更新（関数一覧/ABI_VERSION/差分 API を反映）。
- データフロー図は「diff API を取得して UI 更新」の現在実装に合わせる。
- Test Framework の状態を「設計 → 実装済み」に更新し、現行ドライバ構成へ反映。

---

### D. ロードマップ評価

**現状評価**
- v0.19.0〜v0.21.0 は野心的かつ相互依存が強い。技術的実現性の補強が必要。

**発見した問題点**
- 依存関係の明記不足:
  - v0.20.0 Server Runtime と v0.21.0 Edge は v0.19.0 Database Support の設計/実装に強く依存するが、前提条件が薄い。
- 実現難度が高い領域の前提が不十分:
  - Zig ネイティブ DB ドライバ、WASM + DB、Edge の TCP 制限などの難易度が明示されていない。

**具体的な改善提案**
- v0.19.0〜v0.21.0 について「前提/依存/制約/段階リリース」を明文化（後述のロードマップフィードバック参照）。

---

### E. ユーザビリティ

**現状評価**
- ドキュメント量は豊富だが、初学者向けの導線が分散しており、前提条件の不一致が迷いにつながる。

**発見した問題点**
- Zig バージョンの差分が初心者に混乱を招く。
- README とサイトのプラットフォーム成熟度が一致せず、導線が分岐。
- ルートドキュメントとサイトドキュメントでロードマップが別物になっている。

**具体的な改善提案**
- 「対応 Zig バージョン」「対応プラットフォームの成熟度」を 1 ファイルに集約し、全ドキュメントから参照。
- README からサイトの Getting Started への導線に「最新版はこちら」などの明示を追加。

---

## 3. 優先度付きアクションアイテム

| 優先度 | 項目 | 理由 |
|--------|------|------|
| P0 (Critical) | Zig バージョン/ABI/API の記載統一 | ビルド失敗・実装不一致に直結 |
| P0 (Critical) | `docs/ABI.md` を `core/src/abi.zig` に合わせて更新 | 外部バインディング開発の致命的リスク |
| P1 (High) | `docs/ROADMAP.md` と `docs/ROADMAP.ja.md` の整合修正 | 事業計画の誤解を招く |
| P1 (High) | `site/content/docs/roadmap.*` を現行ロードマップに同期 | 公開情報の陳腐化 |
| P2 (Medium) | v0.16.0〜v0.21.0 の設計ドキュメント追加 | 将来実装の合意形成を容易にする |
| P2 (Medium) | Getting Started に `samples/` 導線を追加 | 初心者の成功率向上 |
| P3 (Low) | 外部リンク検証の自動化 | メンテナンス負荷の低減 |

---

## 4. ロードマップへのフィードバック（v0.19.0〜v0.21.0）

### v0.19.0 Database Support
- **技術的フィードバック**
  - Zig ネイティブで PostgreSQL/MySQL/SQLite/libSQL を同時に維持するには、抽象化レイヤ（接続/クエリ/トランザクション/型変換）を先に定義する必要がある。
  - WASM では TCP が制限されるため、HTTP プロキシ（REST/GraphQL/SQL over HTTP）を公式に想定し、WASM 対応を "proxy-first" にする方が現実的。
  - TLS/証明書/認証 (SASL/SCRAM) の対応計画が必須。
- **欠落している点**
  - マイグレーション/スキーマ管理、接続プール、リトライ戦略、データ型マッピングの方針。
  - Edge 環境向けのストレージ（D1/libSQL/Neon）との整合。

### v0.20.0 Server Runtime (Zylix Server)
- **技術的フィードバック**
  - サーバーランタイムは DB だけでなく、HTTP ルーティング、認証、ログ、設定、監視、エラー分類などの「運用機能」を前提に設計する必要がある。
  - クライアント/サーバー型安全 RPC は Zig 側の型情報公開・スキーマ生成をどうするかが鍵。
  - イベントループ/async ランタイムの設計がエッジ展開に影響する。
- **欠落している点**
  - 認証・認可、セッション管理、レートリミットの基本方針。
  - 「最低限の機能セット（MVP）」の定義。

### v0.21.0 Edge Adapters
- **技術的フィードバック**
  - Cloudflare/Vercel/AWS はランタイム制約が大きく異なるため、共通 API よりも「機能マトリクス＋アダプター」で割り切る設計が必要。
  - Zig→WASM のバイナリサイズ最適化と起動時間は採用の鍵。ロードマップ内で明確な目標値を示すべき。
- **欠落している点**
  - ストレージ/KV/DB の互換性設計（D1、KV、DynamoDB、Neon 等）。
  - エッジ特有の observability（ログ/トレース/メトリクス）設計。

---

## 補足: チェック結果（サイト翻訳）

- `site/content/` の EN/JA ペア差分は未検出。
- `site/i18n/` のキー差分は未検出。

