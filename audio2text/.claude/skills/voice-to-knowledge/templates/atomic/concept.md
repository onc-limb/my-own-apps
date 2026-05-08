---
template: atomic-concept
applies_to_type: concept
saved_to: concepts/
---

# Atomic Template: Concept

「用語定義・概念整理」を1単位で記録する。何度も出てくる用語の意味、固有名詞の解説、業界・組織内ジャーゴンの定義。**用語集**として機能する。

## 抽出基準

- 会話の中で **定義された / 説明された用語**（「XXとは○○のことです」のように）
- 単純に名前が出ただけは不要。定義や説明が伴うものを抽出
- 一度書けば長く使える定義は concept、状況依存の事実は fact 側に

## 出力フォーマット

```markdown
---
type: concept
title: <用語そのもの（"JWT" "ARR" "OKR" のように）>
created_at: <ISO8601 datetime>
recorded_at: <YYYY-MM-DD>
source: sources/<category>/<source-file>.md
aliases:                            # 別名・略称・正式名称
  - <別名1>
  - <別名2>
domain: <例: tech/auth, business/finance, project/foobar>
people:
  - <名前>
project: <プロジェクト名>
tags:
  - <キーワード>
---

# <Title>

## 定義

<簡潔な定義。1〜2文で>

## 詳細説明

<定義を補足する説明。背景、構成要素、仕組みなど>

## 例

<理解を助ける具体例>

- ...

## 関連用語

<上位概念・下位概念・対比される概念>

- 上位概念: [[<broader-concept>]]
- 下位概念: [[<narrower-concept>]]
- 関連: [[<related-concept>]]
- 対比: [[<contrasting-concept>]]

## 出典

- 初出ソース: [[<source-link>]]
- 公式定義: <URL or 書籍>
- 説明者: <名前>

## 注意点 / 誤用されやすい点

<よくある誤解や、文脈による意味の違い>

- ...
```

## 運用方針

- 同じ用語が複数音声に出てきたら、既存の concept ノートを **更新** する（新規作成しない）
- 定義が変わった場合は履歴を本文に追記
- aliases に略称や別名を入れて検索性を確保
