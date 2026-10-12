# stretch-gacha — Claude Code Rules

ストレッチガチャ（iOS / SwiftUI）の実装ルール。仕様の正本は veronica（iron-legion）の
`veronica-docs/stretch-gacha/`。スナップショットが `docs/upstream/` にある。
**仕様を変えたくなったら勝手に実装で逸脱せず、veronica の L1/L2 に戻して更新する。**

## 技術制約（L1 で確定。変更は L1 差し戻し）

- SwiftUI + SwiftData、iOS 17+、iPhone 縦画面固定、XcodeGen（`project.yml`）
- 外部ライブラリ原則ゼロ。サーバー・外部 API・アナリティクス禁止（完全ローカル）
- 通知権限を含む OS 権限を一切要求しない
- 画像・音源アセットを追加しない（視覚は絵文字＋シェイプ、音はハプティクスのみ）
- 画面はガチャ / 図鑑 / 履歴の 3 つまで（モーダルは加算しない）

## 実装規約（L2 の横断決定事項）

- 種目 `id` は実施記録の安定キー。**リネーム・削除禁止**（修正は name/steps のみ）
- 種目追加は `StretchCatalog.json` への追記だけで完結させる（件数・重みをコードに焼き込まない）
- レア度の色は `RarityStyle` が単一の正。再定義しない
- ユーザー向けテキストは `Text(verbatim:)` で描画（LocalizedStringKey 解釈をさせない）
- `print` / `os_log` を書かない
- ロジックは純粋関数に隔離してユニットテストで検証する（GachaDrawer / TimerEngine /
  StreakCalculator / DayNumber / 各 SectionBuilder / SafetyNoticeGate）
- テストは範囲・上限でアサートする（「26 件ちょうど」のような厳密値で追記を壊さない。
  経路差で揺れない値のみ厳密アサート）
- 禁止語（治る・治療・効能・医学・監修・診断・処方）をユーザー向け文言に書かない。
  医学的効能・専門家監修を主張しない

## 検証

- `xcodegen generate` 後、`StretchGacha` スキームでビルド＋テスト（macOS 必須）
- 受け入れ条件の全リストは `docs/upstream/issues/*.md` と各 spec を参照
