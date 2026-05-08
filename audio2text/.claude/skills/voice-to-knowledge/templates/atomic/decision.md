---
template: atomic-decision
applies_to_type: decision
saved_to: decisions/
---

# Atomic Template: Decision

「決まったこと」を1単位で記録する。複数の決定が1つの音声から出る場合は、それぞれを別ファイルにする。

## 抽出基準

- 「やる/やらない」「選ぶ/選ばない」「Aに合意した」のように **意思決定** が読み取れるもの
- 単なる「検討中」「保留」は decision ではなく `question/` に
- 完全に確定していなくても「現時点での方向性」として残す価値があれば status を `proposed` で残す

## 出力フォーマット

```markdown
---
type: decision
title: <決定内容を表す短い文（"Q3リリース日を8/15に確定" のように完結文）>
created_at: <ISO8601 datetime>
recorded_at: <YYYY-MM-DD>
source: sources/<category>/<source-file>.md
status: proposed | confirmed | superseded   # 提案中 / 確定 / 上書きされた
decided_at: <YYYY-MM-DD or unknown>          # 決定された日付
deciders:                                    # 意思決定者
  - <名前 or 役割>
people:                                      # 関連人物（影響を受ける人含む）
  - <名前>
project: <プロジェクト名>
tags:
  - <キーワード>
---

# <Title>

## 決定内容

<1〜3文で何が決まったかを明確に>

## 背景・理由

<なぜそう決まったか。議論の経緯、判断材料>

## 影響範囲

<この決定によって影響を受ける人・もの・スケジュール>

## 制約条件 / 前提

<決定の前提となる条件。前提が崩れれば再検討が必要>

- ...

## 関連

- Source: [[<source-link>]]
- Related decisions: [[<related-decision>]]
- Tasks generated: [[<task-link>]]
- Reverses: [[<superseded-decision>]] (このノートが上書きする旧決定があれば)
```

## status の遷移

- `proposed` → `confirmed`: 後の音声で再確認・実施が始まったとき
- `confirmed` → `superseded`: 後で覆された場合。新しい decision ノートを作り、こちらの status を変更し `superseded_by` でリンク
