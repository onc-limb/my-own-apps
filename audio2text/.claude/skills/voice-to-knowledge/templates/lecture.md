---
name: lecture
description: 講演・プレゼン・教材音声。学習素材として再利用可能な形に再構成する。
applies_to:
  - lecture
focus_priority:
  - 章立て・主題の構造
  - キーコンセプトと定義
  - 例・反例
  - 要復習事項
tone: educational
---

# Summary Template: Lecture / Presentation

講演や学習素材を**後で読み返して理解できる教材形式**に再構成する。話の流れの再現よりも、内容の構造化を重視。

## 抽出時の基本方針

- 講演の章立てを推測して再構成（話者がアジェンダを示している場合はそれを尊重）
- 用語の定義は別セクションに集約（後から参照しやすくする）
- 「例として～」「具体的には～」のような例示は学習価値が高いので必ず残す
- 強調された内容（「ここが重要」「忘れないでください」等）は別途マーキング
- 質疑応答があれば別セクションに

## 出力フォーマット

```markdown
---
title: <講演タイトル>
source_audio: <元音声ファイル名>
source_transcript: <transcript .md ファイル名>
recorded_at: <YYYY-MM-DD>
processed_at: <ISO8601>
category: lecture
preset: <使用したプリセット名>
template: lecture
language: <ja|en|...>
duration: <HH:MM:SS>
speaker: <話者名 or 役職>
project: <プロジェクト名>
tags:
  - <キーワード1>
extracted_notes:
  decisions: []
  tasks: []
  facts: []
  ideas: []
  insights: []
  questions: []
  concepts: []
---

# <Title>

## TL;DR

<3〜5文で「何の講演で、何を学べるか」>

## 章立て / アジェンダ

1. <章タイトル>
2. <章タイトル>
3. ...

## 各章の要点

### 1. <章タイトル>

<要点を箇条書き>

- ...

**例 / 具体例:**
- ...

### 2. <章タイトル>
- ...

## キーコンセプト / 定義

| 用語 | 定義 | 補足 |
|---|---|---|
| <用語> | <定義> | <文脈・例> |

## 強調された主張

<話者が「ここが重要」と明示した内容>

- **<主張>** — <根拠>

## 質疑応答（あれば）

### Q. <質問>
A. <回答要約>

## 要復習事項

<理解が難しかった点、自分で深掘りしたい点>

- ...

## 参考文献 / 言及されたリソース

<書籍名・URL・人物名等>

- ...

## キーワード

`<keyword1>` `<keyword2>` ...

## 引用 / 印象的な発言

<3〜8 個。記憶に残したい一節>

- `[HH:MM:SS]` "<発言>"

## 抽出されたアトミックノート

<!-- 講演は concepts（用語）/ facts（教えられた事実）/ insights（自分なりの学び）が中心 -->

### 用語・概念
- [[concepts/2026-MM-DD_xxx]] — <タイトル>

### 知識・事実
- [[facts/2026-MM-DD_xxx]] — <タイトル>

### 学び・気付き
- [[insights/2026-MM-DD_xxx]] — <タイトル>

### 復習したい問い
- [[questions/2026-MM-DD_xxx]] — <タイトル>

### アイデア
- [[ideas/2026-MM-DD_xxx]] — <タイトル>

### 自分への TODO
- [[tasks/2026-MM-DD_xxx]] — <タイトル>

### 決定（自分の方針として採用したいこと）
- [[decisions/2026-MM-DD_xxx]] — <タイトル>

## 関連ナレッジ

- [[sources/<category>/<related-file>]]
```

## 注意

- 教材として使う場合は、話者の表現を尊重しつつも理解しやすく整理する
- 推測が混じる場合は `<!-- 推測: ... -->` で明記
