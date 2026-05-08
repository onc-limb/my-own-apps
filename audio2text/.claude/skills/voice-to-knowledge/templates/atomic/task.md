---
template: atomic-task
applies_to_type: task
saved_to: tasks/
---

# Atomic Template: Task

「やる必要があること」を1単位で記録する。会議で発生したアクションアイテム、自分への TODO、誰かへの依頼など。

## 抽出基準

- 「Xする」「Yに連絡する」「Zを確認する」のように **行動可能** な表現があるもの
- 期日や担当者が不明でも、行動が明確なら抽出する（後で埋めればよい）
- 単なる「やった方がいい」は idea や question 寄り

## 出力フォーマット

```markdown
---
type: task
title: <タスクを表す動詞始まりの短い文（"README を更新する" のように）>
created_at: <ISO8601 datetime>
recorded_at: <YYYY-MM-DD>
source: sources/<category>/<source-file>.md
status: pending | in-progress | done | blocked | dropped
priority: high | medium | low
assignee: <名前 or self or unknown>
due: <YYYY-MM-DD or unknown>
people:
  - <名前>
project: <プロジェクト名>
tags:
  - <キーワード>
---

# <Title>

## やること

<1〜2文で具体的な行動を記述。実行のしかたが分かるレベルで>

## 背景

<なぜこのタスクが発生したか>

## 完了条件

<どうなったら done と言えるか>

- [ ] <条件1>
- [ ] <条件2>

## 依存

<このタスクが他のタスクや決定に依存していれば>

- Blocks: [[<blocked-task>]]
- Blocked by: [[<blocking-task>]]
- Depends on decision: [[<decision>]]

## 関連

- Source: [[<source-link>]]
- Related: [[<related>]]

## メモ / 進捗ログ

<!-- 後から進捗を追記していく -->

- <YYYY-MM-DD>: <進捗・気付き>
```

## status 運用

- `pending`: 着手前
- `in-progress`: 着手済み
- `done`: 完了（完了日付をメモに記録）
- `blocked`: 何かに阻まれている（理由をメモに）
- `dropped`: もうやらない判断（理由をメモに）
