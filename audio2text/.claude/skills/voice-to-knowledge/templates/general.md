---
name: general
description: 分類できない音声 / 上記テンプレートに当てはまらない場合の汎用テンプレート。
applies_to:
  - general
focus_priority:
  - 概要
  - トピック
  - 知見
  - 引用
tone: neutral
---

# Summary Template: General

特定のシーンに紐づかない、汎用的な要約テンプレート。**情報の取りこぼしを最小化することを優先**し、構造はシンプルに保つ。

## 抽出時の基本方針

- 「何の音声か」をまず把握し、TL;DR で表現
- 議論があるなら主要トピックに分解
- 結論や決定があれば明示、なければ「未着地」と記録
- 後で読み返した時に文脈が分かるよう、十分な引用を残す

## 出力フォーマット

```markdown
---
title: <内容を表す短いタイトル>
source_audio: <元音声ファイル名>
source_transcript: <transcript .md ファイル名>
recorded_at: <YYYY-MM-DD>
processed_at: <ISO8601>
category: general
preset: <使用したプリセット名>
template: general
language: <ja|en|...>
duration: <HH:MM:SS>
participants:
  - <名前 or 役割>
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

<3〜5文で全体を要約>

## 主要トピック

- **<トピック>**: <要点>

## 重要なポイント / 知見

- ...

## 登場人物・場所

- ...

## 決定事項 / 結論（あれば）

- ...

## 未解決の論点 / 次の課題（あれば）

- ...

## キーワード

`<keyword1>` `<keyword2>` ...

## 引用 / 重要発言

- `[HH:MM:SS]` <発言>

## 抽出されたアトミックノート

<!-- 該当するものだけ残し、不要なセクションは空でも OK -->

### 決定事項
- [[decisions/2026-MM-DD_xxx]] — <タイトル>

### タスク
- [[tasks/2026-MM-DD_xxx]] — <タイトル>

### 知識・事実
- [[facts/2026-MM-DD_xxx]] — <タイトル>

### アイデア
- [[ideas/2026-MM-DD_xxx]] — <タイトル>

### 学び・気付き
- [[insights/2026-MM-DD_xxx]] — <タイトル>

### 未解決の問い
- [[questions/2026-MM-DD_xxx]] — <タイトル>

### 用語・概念
- [[concepts/2026-MM-DD_xxx]] — <タイトル>

## 関連ナレッジ

- [[sources/<category>/<related-file>]]
```

## 注意

- 個人情報は `[REDACTED]` でマスク
- 推測が混じる場合は `<!-- 推測: ... -->` で明記
- このテンプレートを使うことが多い場合は、専用テンプレートを別途作成することを検討
