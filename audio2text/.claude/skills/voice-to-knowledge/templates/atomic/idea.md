---
template: atomic-idea
applies_to_type: idea
saved_to: ideas/
---

# Atomic Template: Idea

「採否未定で寝かせる発想・仮説」を1単位で記録する。決定でも事実でもなく、まだ形にならないが捨てたくないもの。

## 抽出基準

- 「○○できそう」「もし○○なら」「△△を試したい」のような **仮説・提案・思いつき**
- 既に決まったものは decision、既に分かっている事実は fact
- 漠然とした「○○について考えるべき」は question 寄り

## 出力フォーマット

```markdown
---
type: idea
title: <アイデアを表す短い文（"Redis でキャッシュ無効化を非同期化する" のように）>
created_at: <ISO8601 datetime>
recorded_at: <YYYY-MM-DD>
source: sources/<category>/<source-file>.md
status: raw | exploring | validated | abandoned   # 生 / 調査中 / 妥当性確認済み / 廃案
value_estimate: high | medium | low | unknown      # 期待効果
effort_estimate: high | medium | low | unknown     # 実装コスト
proponent: <発案者 or self>
people:
  - <名前>
project: <プロジェクト名>
tags:
  - <キーワード>
---

# <Title>

## アイデア

<1〜3文で発想を述べる>

## 動機 / 解決したい課題

<このアイデアが何を解決しようとしているか>

## 想定される効果

<実現したらどうなるか>

- ...

## 検証方法 / 次のステップ

<このアイデアを進めるためにすべきこと>

- [ ] <ステップ1>
- [ ] <ステップ2>

## 懸念 / リスク

<潜在的な問題、見落としがちな点>

- ...

## 関連

- Source: [[<source-link>]]
- Related ideas: [[<related-idea>]]
- Inspired by: [[<related-fact-or-insight>]]
- Promoted to decision: [[<decision-link>]]   # 採用された場合
```

## status の運用

- `raw`: 思いつきのまま、未検討
- `exploring`: 調査・実験中
- `validated`: 妥当性が確認できた（decision に昇格させる候補）
- `abandoned`: 採用しないと判断（理由を本文に追記）
