---
name: monologue
description: 独り言・思考メモ・運転中録音など、自分一人の発話を整理する。
applies_to:
  - monologue
focus_priority:
  - 思考のテーマ
  - 結論 / 暫定結論
  - 未解決の問い
  - 自分への TODO
tone: personal / reflective
---

# Summary Template: Monologue / Thought Memo

自分の独り言・思考を**思考の流れを残しつつ構造化する**ためのテンプレート。

## 抽出時の基本方針

- 結論が出ていない / 矛盾している思考も**そのまま残す**ことに価値がある
- 「考えていたテーマ」を上位概念として括る
- 「次に動くべきこと」を最後に明示。一人語りは行動につながらないと無意味になりがち
- 感情の動き（イライラ、納得、興奮）も思考のメタ情報として記録
- 文意が不明な部分は無理に整形せず、引用として残す

## 出力フォーマット

```markdown
---
title: <思考のテーマを表す短いタイトル>
source_audio: <元音声ファイル名>
source_transcript: <transcript .md ファイル名>
recorded_at: <YYYY-MM-DD>
processed_at: <ISO8601>
category: monologue
preset: <使用したプリセット名>
template: monologue
language: <ja|en|...>
duration: <HH:MM:SS>
mood: <例: focused / restless / excited / frustrated>
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

<2〜3文で「何について考えて、どこに着地したか」>

## 考察のテーマ

<話の中心にあるテーマ。複数あれば並列で>

- ...

## 思考の流れ

<論理の流れを箇条書き。引用を交えつつ。途中で方向が変わったらその転換点を明示>

1. <最初の問題意識>
2. <これに対する仮説>
3. <反証や疑問>
4. <暫定的な着地点>

## 結論 / 暫定結論

<その時点で出た答え。出ていなければ「未着地」と書く>

- ...

## 未解決の問い

<考え終わらなかったこと。次の思考のフックになるもの>

- ...

## 自分への TODO

<行動につなげる>

- [ ] <内容>

## 関連する記憶 / アイデア

<会話中に出てきた過去の出来事、別のアイデアへの参照>

- ...

## キーワード

`<keyword1>` `<keyword2>` ...

## 引用 / 印象的な独白

<3〜5 個。考えのクリスタルになっている発言>

- `[HH:MM:SS]` <発言>

## 抽出されたアトミックノート

<!-- 独り言は ideas / insights / questions / tasks（自分宛） が中心になりやすい -->

### 自分への TODO（タスク）
- [[tasks/2026-MM-DD_xxx]] — <タイトル>

### アイデア・仮説
- [[ideas/2026-MM-DD_xxx]] — <タイトル>

### 学び・気付き
- [[insights/2026-MM-DD_xxx]] — <タイトル>

### 未解決の問い
- [[questions/2026-MM-DD_xxx]] — <タイトル>

### 暫定的に決めたこと
- [[decisions/2026-MM-DD_xxx]] — <タイトル>

### 用語・概念（自分なりの定義）
- [[concepts/2026-MM-DD_xxx]] — <タイトル>

### 知識・事実
- [[facts/2026-MM-DD_xxx]] — <タイトル>

## 関連ナレッジ

- [[sources/<category>/<related-file>]]
```

## 注意

- 意味が通らない / 不明瞭な部分は「一貫性のために改変する」のではなく `[判読不能]` 等で残す
- 推測が混じる場合は `<!-- 推測: ... -->` で明記
