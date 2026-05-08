---
template: atomic-insight
applies_to_type: insight
saved_to: insights/
---

# Atomic Template: Insight

「気付き・教訓・学び」を1単位で記録する。自分の認識が変わった瞬間、過去の経験から得た原則、メタ認知。**自分の成長ログ**として機能する。

## 抽出基準

- 「○○だと思った」「○○を学んだ」「○○な傾向がある」のような **主観的気付き** や **抽象化された教訓**
- 客観的事実は fact 側に
- 単なる発想・提案は idea 側に
- 「この経験は次に活かせる」と思えるものを残す

## 出力フォーマット

```markdown
---
type: insight
title: <気付きを表す短い文（"早期に手を動かして検証する方が議論より速い" のように）>
created_at: <ISO8601 datetime>
recorded_at: <YYYY-MM-DD>
source: sources/<category>/<source-file>.md
trigger: <気付きのきっかけとなった出来事 / 発言 / 状況>
domain: <例: leadership, engineering, communication, life>
applicability: general | situational     # 一般化できるか、特定状況限定か
people:
  - <名前>
project: <プロジェクト名>
tags:
  - <キーワード>
---

# <Title>

## 気付き

<1〜3文で何に気付いたか。一般化された形で>

## トリガー

<この気付きを得たきっかけ。具体的な出来事や発言>

> <該当する引用やシーン>

## 自分への適用

<この気付きを自分のどんな場面で活かせるか>

- ...

## 反例 / 例外

<この気付きが当てはまらないケース。原則の境界を明確にする>

- ...

## 関連

- Source: [[<source-link>]]
- Related insights: [[<related-insight>]]
- Spawned tasks: [[<task-link>]]   # 行動につながった場合
- Spawned ideas: [[<idea-link>]]
```

## 良い insight の条件

- 1段階抽象化されている（「あの会議で○○さんが××と言った」ではなく「○○な状況では××が有効」）
- 後で別の状況に適用できる
- 自分の認識の変化を含む（before/after）
