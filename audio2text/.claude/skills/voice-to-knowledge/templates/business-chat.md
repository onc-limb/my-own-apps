---
name: business-chat
description: 仕事上の雑談・1on1・廊下会話。決定よりも「気付き」「関係性」「業務に活きる発見」を拾う。
applies_to:
  - business-chat
focus_priority:
  - 業務に関連する発見・アイデア
  - 関係者の所感・温度感
  - 後で確認したいことリスト
  - 関係性の変化
tone: business / casual
---

# Summary Template: Business Casual Chat

形式的な議事録ではなく、**「会話から拾える業務的な手がかり」を残す**ためのテンプレート。

## 抽出時の基本方針

- 結論や決定が出ていない会話が普通。**「フックになる発言」を拾う**ことに注力
- 相手の温度感（前向き / 慎重 / 困惑など）を読み取って記載
- 「後で誰々に聞いたほうがいい」「この件はフォローしよう」のような行動の種を拾う
- 個人の評価・噂話は記載しない（記載するなら抽象化する）
- TODO は「自分が動くべきこと」に絞る（決定事項リストではない）

## 出力フォーマット

```markdown
---
title: <雑談の主題を表す短いタイトル>
source_audio: <元音声ファイル名>
source_transcript: <transcript .md ファイル名>
recorded_at: <YYYY-MM-DD>
processed_at: <ISO8601>
category: business-chat
preset: <使用したプリセット名>
template: business-chat
language: <ja|en|...>
duration: <HH:MM:SS>
participants:
  - <相手の名前 or 役割>
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

<2〜3文で「誰と何の話をして、自分が何を持ち帰ったか」>

## 話題

<話の流れを大まかに。時系列やトピック単位で>

- **<話題1>**: <要点>
- **<話題2>**: <要点>

## 業務に活きそうな発見

<会話から得られた業務的価値のあるもの。直接的でなくてもよい>

- ...

## 相手の温度感・所感

<相手の発言から読み取れる態度。「賛成だが慎重」「困っている」等>

- **<相手>**: <温度感>

## 自分のフォローアップ

<自分が後で動くべきこと。雑な TODO で良い>

- [ ] <内容>

## 後で確認したいこと / 質問の種

<その場で結論が出なかった疑問や、誰かに聞いたほうがいい事項>

- ...

## キーワード

`<keyword1>` `<keyword2>` ...

## 引用 / 印象に残った発言

<3〜5 個。後で文脈を思い出すためのアンカー>

- `[HH:MM:SS]` <発言>

## 抽出されたアトミックノート

<!-- 雑談からも積極的に拾う。特に ideas / questions / insights / facts は出やすい -->

### 決定事項
- [[decisions/2026-MM-DD_xxx]] — <タイトル>

### タスク（自分のフォローアップ）
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

- 個人の評価・噂・センシティブな情報は記録に向かない。書く場合は最小限・抽象化する
- 推測が混じる場合は `<!-- 推測: ... -->` で明記
