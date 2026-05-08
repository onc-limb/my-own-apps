---
name: private-chat
description: プライベートな雑談（家族・友人）。出来事・人物・関係性・約束を記録する。
applies_to:
  - private-chat
focus_priority:
  - 出来事
  - 登場人物
  - 約束・予定
  - 感情の動き
tone: personal / casual
---

# Summary Template: Private Chat

仕事ではない私的な会話を記録する。**個人的な思い出・関係性のメモ帳**として機能させる。

## 抽出時の基本方針

- 「何があったか」「誰が出てきたか」「何を約束したか」を中心に
- 業務的な視点（決定 / アクション）は不要。代わりに「感情の動き」「関係性の機微」を拾う
- 第三者の評価・噂は最小限。書く場合も抽象化
- ジョーク・印象的なフレーズは引用として残しておくと後で読み返した時に楽しい
- センシティブな情報（健康・人間関係の悩み等）は本人の意向に応じて慎重に扱う

## 出力フォーマット

```markdown
---
title: <会話のテーマや出来事を表す短いタイトル>
source_audio: <元音声ファイル名>
source_transcript: <transcript .md ファイル名>
recorded_at: <YYYY-MM-DD>
processed_at: <ISO8601>
category: private-chat
preset: <使用したプリセット名>
template: private-chat
language: <ja|en|...>
duration: <HH:MM:SS>
participants:
  - <名前 or 関係性: 例「妻」「友人A」>
mood: <例: relaxed / nostalgic / heated / fun>
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

<2〜3文で「誰と何の話をしたか、何が印象的だったか」>

## 話題

<話の流れを大まかに>

- **<話題1>**: <要点>
- **<話題2>**: <要点>

## 出来事 / エピソード

<会話で語られた出来事を時系列か重要度順で>

- ...

## 登場人物 / 場所

- **<名前 or 関係性>**: <文脈・話題との関連>
- **<場所>**: <会話で言及された場面>

## 約束 / 予定

<会話で決まった約束・次の予定>

- [ ] <内容> (日時: <?>, 相手: <?>)

## 感情の動き

<会話を通じての感情の流れ>

- ...

## 印象的なフレーズ / ジョーク

<引用として残しておきたい言葉>

- `[HH:MM:SS]` "<発言>"

## キーワード

`<keyword1>` `<keyword2>` ...

## 抽出されたアトミックノート

<!-- プライベート会話は tasks（約束）/ insights / facts（生活情報）が出やすい。decisions も「行く先」「日程」など軽いものを -->

### 約束・予定（タスク）
- [[tasks/2026-MM-DD_xxx]] — <タイトル>

### 決まったこと
- [[decisions/2026-MM-DD_xxx]] — <タイトル>

### 学び・気付き
- [[insights/2026-MM-DD_xxx]] — <タイトル>

### 知識・事実（生活情報・経験談）
- [[facts/2026-MM-DD_xxx]] — <タイトル>

### アイデア
- [[ideas/2026-MM-DD_xxx]] — <タイトル>

### 未解決の問い
- [[questions/2026-MM-DD_xxx]] — <タイトル>

### 用語・概念
- [[concepts/2026-MM-DD_xxx]] — <タイトル>

## 関連ナレッジ

- [[sources/<category>/<related-file>]]
```

## 注意

- 第三者についての評価的内容は最小限に。書くなら抽象化
- センシティブな話題が含まれる場合、`category` に sensitive のような補助タグを足すか、そもそも記録を控える選択も検討
- 推測が混じる場合は `<!-- 推測: ... -->` で明記
