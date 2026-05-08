---
name: interview
description: インタビュー・対話形式。Q&A 構造を保ちつつ重要発言を引用する。
applies_to:
  - interview
focus_priority:
  - 質問項目
  - 回答の要点
  - 印象的な引用
  - フォローアップ質問の種
tone: business or journalistic
---

# Summary Template: Interview

インタビュー音声を**Q&A の構造を保ちながら知識化**する。発言の言葉そのものに価値があるため、引用を多めに残す。

## 抽出時の基本方針

- 質問→回答の対応を可能な限り維持
- 回答は要約と原文引用の両方を残す（引用が後で重要な根拠になることが多い）
- インタビュアーが省略した質問の意図、被取材者の言外の情報も推測コメントで残せると良い
- フィラー（「えーっと」「あの」）の言い淀みも、答えに迷っている場面では情報として有用な場合あり
- 後でフォローアップしたい話題を「次の質問の種」として残す

## 出力フォーマット

```markdown
---
title: <インタビューのテーマ or 被取材者を表すタイトル>
source_audio: <元音声ファイル名>
source_transcript: <transcript .md ファイル名>
recorded_at: <YYYY-MM-DD>
processed_at: <ISO8601>
category: interview
preset: <使用したプリセット名>
template: interview
language: <ja|en|...>
duration: <HH:MM:SS>
participants:
  - <被取材者>
  - <インタビュアー>
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

<3〜5文で「誰に何を聞いて、何が分かったか」>

## 主要な発見 / 結論

<インタビューを通して得られた中心的な知見>

- ...

## Q&A サマリ

### Q1. <質問>

**回答要約:** <2〜3文で要約>

**重要な引用:**
- `[HH:MM:SS]` "<発言>"
- `[HH:MM:SS]` "<発言>"

### Q2. <質問>

**回答要約:** ...

**重要な引用:**
- `[HH:MM:SS]` "<発言>"

## 被取材者の人物像 / 立場

<発言から読み取れる経歴・専門・立場>

- ...

## フォローアップ質問の種

<次に聞きたいこと、深掘りしたいこと>

- ...

## キーワード

`<keyword1>` `<keyword2>` ...

## 抽出されたアトミックノート

<!-- インタビューは facts（被取材者の発言事実）/ insights / questions（次の質問）が中心 -->

### 知識・事実（被取材者の発言）
- [[facts/2026-MM-DD_xxx]] — <タイトル>

### 学び・気付き
- [[insights/2026-MM-DD_xxx]] — <タイトル>

### 次の質問の種
- [[questions/2026-MM-DD_xxx]] — <タイトル>

### 用語・概念
- [[concepts/2026-MM-DD_xxx]] — <タイトル>

### アイデア（取材から派生）
- [[ideas/2026-MM-DD_xxx]] — <タイトル>

### タスク
- [[tasks/2026-MM-DD_xxx]] — <タイトル>

### 決定事項
- [[decisions/2026-MM-DD_xxx]] — <タイトル>

## 関連ナレッジ

- [[sources/<category>/<related-file>]]
```

## 注意

- 個人情報・機密情報の取り扱いは、被取材者の意向を優先。記録に残す前に確認が必要な場合がある
- 推測が混じる場合は `<!-- 推測: ... -->` で明記
