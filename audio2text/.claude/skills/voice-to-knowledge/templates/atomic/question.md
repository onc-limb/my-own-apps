---
template: atomic-question
applies_to_type: question
saved_to: questions/
---

# Atomic Template: Question

「未解決の問い・調べたいこと」を1単位で記録する。あとで答えを探したい疑問、決められなかった論点、誰かに聞きたいこと。

## 抽出基準

- 「○○ってどうなんだろう」「○○について調べる必要がある」のような **未解決の論点**
- 答えが既に出ているなら fact / decision に分類
- 行動が明確なら task 寄り（ただし「調査する」というタスクなら question にして関連 task を作る形でも可）

## 出力フォーマット

```markdown
---
type: question
title: <問いを表す疑問形の短い文（"なぜ Q3 のリリース日を 8/15 にしたのか?" のように）>
created_at: <ISO8601 datetime>
recorded_at: <YYYY-MM-DD>
source: sources/<category>/<source-file>.md
status: open | investigating | answered | dropped
priority: high | medium | low
asker: <発問者 or self>
answer_target: <答えを探す対象: 例「山田さん」「ドキュメントAxを読む」「自分で実験」>
deadline: <YYYY-MM-DD or unknown>
people:
  - <名前>
project: <プロジェクト名>
tags:
  - <キーワード>
---

# <Title>

## 問い

<疑問を明確に。具体的・答えられる形で>

## 背景

<なぜこの問いが生まれたか>

## 何が分かれば答えと言えるか

<答えの輪郭。これが書けないと、調べても答えに辿り着けない>

- ...

## 調査の手がかり

<答えを得るための糸口>

- 質問する相手: <名前>
- 参照すべき資料: <URL / 本 / ドキュメント名>
- 試すべき実験: <内容>

## 関連

- Source: [[<source-link>]]
- Related questions: [[<related-question>]]
- Spawned tasks: [[<task-link>]]
- Answered by: [[<fact-link>]]   # 答えが出たときに張る
```

## status の運用

- `open`: 未着手
- `investigating`: 調査中
- `answered`: 答えが出た。`Answered by` で fact / decision にリンク
- `dropped`: 重要でないと判断、もう追わない
