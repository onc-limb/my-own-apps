# 2026-06-10 telos — フリーランス向けツール追加（Positioning / Retrospective）

## 経緯

「フリーランスエンジニアとして上手くビジネスに入っていける機能」を複数提案 → ユーザーが
提案の **②Positioning** と **⑥Retrospective** を採用、実装を指示。

提案した6案（記録用）: ①Proposal ②Positioning ③Estimate/Scope ④Change Log
⑤Decision Log ⑥Retrospective。案件ライフサイクル（入口を勝つ→お金を守る→信頼を積む）で整理。
未採用分は今後の候補として残す。

## 実装した2つ

### Positioning（自分の価値の言語化）
- フリーランスの入口（front of funnel）。「何屋さんか」を一文に。
- Goals の JTBD 思想（誰の・どんな進歩を・どう）を**自分自身に向けた**構成。
- 成果物はバリューステートメントの白い「紙」。プロフィール・営業文・提案冒頭に流用する想定。

### Retrospective（振り返り→継続提案）
- 出口（リピート・紹介）。Keep/Problem の振り返りを構造化し、継続提案文に変換。
- AI なしでもテンプレで提案文を組める（成果→残課題→次の一手）。AI 有効時は LLM が生成。

## 設計判断

- **既存パターンを踏襲**: localStorage 永続化、任意 AI 支援（OFF でもヒューリスティックで動く）、
  成果物は白い紙、split エディタ + プレビュー。新しい発明はせず telos の型に乗せた。
- **Positioning と Retrospective を別ツールに分けた**: 入口と出口で JTBD（遂げたい進歩）が
  別物のため。一方は「受注前に価値を固める」、もう一方は「納品後に次を取りに行く」。
- これで telos は「目的発見(Goals)→提案/価値(Positioning)→報告(Slides)→説明(Brief)→
  継続(Retro)」と案件の入口から継続までを貫く構成になった。

## 宿題

- 未実装の提案（Proposal / Estimate/Scope / Decision Log / Change Log）。特に Estimate/Scope は
  「含まないことの明示」で赤字を防ぐ効果が大きく、次の有力候補。
