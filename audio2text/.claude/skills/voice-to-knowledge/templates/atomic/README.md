# Atomic Note Templates

ソースノート（1音声 = 1ファイル）から抽出される**原子的な知識単位**のテンプレート集。

## 7種の type

| type | 格納先 | 何を残すか |
|---|---|---|
| `decision` | `decisions/` | 決定事項・合意・約束（「Xすることに決めた」） |
| `task` | `tasks/` | アクションアイテム（期日付き or 期日不明でも要やること） |
| `fact` | `facts/` | 事実・技術知識・定義済み情報（再利用可能なナレッジ） |
| `idea` | `ideas/` | アイデア・仮説（採否未定で寝かせるもの） |
| `insight` | `insights/` | 学び・気付き・教訓（自分の成長ログ） |
| `question` | `questions/` | 未解決の問い・調べたいこと |
| `concept` | `concepts/` | 用語定義・概念整理（用語集） |

## 粒度ルール（重要）

| ルール | 説明 |
|---|---|
| **1ノート = 1テーマ** | 「Q3リリース」と「予算削減」が同じ会議で決まったら、ノートも2枚に分ける |
| **タイトルが完結文か** | "Q3リリース日を8/15に確定" のように、タイトルだけで意味が分かる |
| **必ず source を持つ** | frontmatter に `source:` で `sources/<...>.md` へのリンク |
| **更新可能** | 後で別音声から関連情報が出たら追記する。アトミックノートは生きている |

## ファイル名規則

`YYYY-MM-DD_<slug>.md`

- `YYYY-MM-DD`: 録音日（録音日不明なら処理日）
- `<slug>`: タイトルから生成。日本語可。30文字以内。空白は `-` に
- 同日重複時: 末尾に `-2` `-3` を付与

例:
- `decisions/2026-05-08_q3-リリース日を8-15に確定.md`
- `tasks/2026-05-08_README更新-yamada-5-15.md`
- `facts/2026-05-08_jwt-rotation-policy.md`

## frontmatter 共通フィールド

すべての atomic note は以下の共通フィールドを持つ:

```yaml
---
type: <decision|task|fact|idea|insight|question|concept>
title: <短いタイトル>
created_at: <ISO8601 datetime>     # ノート生成日時
recorded_at: <YYYY-MM-DD>           # 元音声の録音日
source: sources/<category>/<file>.md
people: [<人名>, ...]               # 関連人物
project: <プロジェクト名>            # 任意
tags: [<タグ>, ...]                 # 自由タグ
---
```

各 type に固有のフィールドはテンプレート側に追加されている。
