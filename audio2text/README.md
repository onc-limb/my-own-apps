# audio2text

OSS の Whisper（whisper.cpp）でローカルに長時間（2時間規模）の会話音声を文字起こしし、Claude が要約・知識マップ化しやすい Markdown を出力する CLI。

**API キー不要・完全オフライン・コストゼロ。**

## 特徴

- **完全ローカル実行** — `whisper.cpp` ベースの `nodejs-whisper` を使用。データは外部に出ない。
- **2時間音声対応** — whisper.cpp は内部で 30秒ウィンドウのスライディング処理をするためメモリは一定。
- **複数フォーマット** — `md` / `txt` / `srt` / `vtt` / `json` を選択可能。
- **Claude フレンドリーな Markdown** — frontmatter、Summary Hooks、タイムスタンプ付きセグメントを自動生成。
- **モデル豊富** — `tiny` から `large-v3-turbo` まで 11 モデルから選択可能。
- **ffmpeg 同梱** — システム ffmpeg 不要（`ffmpeg-static` 内包）。

## セットアップ

```bash
cd audio2text
npm install   # 初回のみ whisper.cpp ビルドが走る
npm run build
```

**ビルド要件:**
- Node.js 18+
- C/C++ コンパイラ（macOS: `xcode-select --install` / Ubuntu: `sudo apt install build-essential` / Windows: MSYS2 か MinGW-w64）

初回実行時に Whisper モデルが自動ダウンロードされます（保存先: `~/.audio2text/models/`）。事前ダウンロードするには:

```bash
npx nodejs-whisper download
```

## 使い方

### 基本

```bash
node dist/index.js path/to/recording.m4a
# → path/to/recording.md が生成される（base モデル）
```

### 日本語の打ち合わせを高精度で

```bash
node dist/index.js meeting.mp3 \
  --model large-v3-turbo \
  --language ja \
  --title "2026-05-08 定例MTG"
```

### モデル一覧を見る

```bash
node dist/index.js models
```

### 開発時

```bash
npm run dev -- meeting.mp3 -m small
```

## CLI オプション

| オプション | 説明 | デフォルト |
|---|---|---|
| `<input>` | 入力音声/動画ファイル | — |
| `-f, --format` | 出力形式 (`md`/`txt`/`srt`/`vtt`/`json`) | `md` |
| `-o, --output` | 出力先パス | 入力と同じディレクトリ |
| `-l, --language` | 言語コード（指定すると自動検出をスキップ） | 自動 |
| `-m, --model` | モデル ID（下記一覧参照） | `base` |
| `-t, --title` | Markdown タイトル | ファイル名 |
| `--model-root` | モデル保存先 | `~/.audio2text/models` |
| `--segment-length <n>` | 1セグメントの最大トークン数 (whisper.cpp `-ml`) | `20` |
| `--word-timestamps` | 単語ごとのタイムスタンプを出力 | off |
| `--preprocess <list>` | ffmpeg 前処理パイプライン（カンマ区切り） | なし |
| `--postprocess <list>` | 文字起こし後処理パイプライン（カンマ区切り） | なし |
| `--paragraph-gap <sec>` | 段落区切りとみなす無音時間 | `2.0` |
| `-p, --prompt <text>` | 文字起こしを誘導するコンテキストプロンプト | — |
| `--prompt-file <path>` | プロンプトをファイルから読み込み | — |
| `--keep-temp` | 一時ファイル（wav/json）を残す | `false` |
| `models` (サブコマンド) | サポートモデルの一覧表示 | — |

### `--preprocess` で利用可能なステップ

ffmpeg フィルタを指定順にチェーンする。複数指定はカンマ区切り（例: `--preprocess silence-trim,normalize`）:

| ステップ | 効果 | 効くケース |
|---|---|---|
| `silence-trim` | 無音区間 (-50dB / 1秒以上) をカット | 沈黙が多い録音、Whisper の幻覚抑制、処理時間短縮 |
| `normalize` | EBU R128 ベースの音量正規化 | 録音レベルがばらつく、ボソボソ声、声が小さい |
| `denoise` | FFT ベースのノイズ除去 | 空調音、ホワイトノイズが多い録音 |
| `voice-band` | 80Hz-8kHz の人声帯域フィルタ | 低周波振動・不要な高域ノイズの除去 |

### `--prompt` の使い方

固有名詞・専門用語・スタイルを Whisper に伝えると認識精度が向上する:

```bash
node dist/index.js meeting.mp3 \
  --prompt "参加者: 山田、佐藤。プロダクト: Foobar API、Acme SDK。専門用語: KPI, ARR, CAC, LTV"
```

長文プロンプトはファイル経由が安全:

```bash
node dist/index.js meeting.mp3 --prompt-file prompts/meeting.txt
```

実装は `nodejs-whisper` の `whisperOptions` に `prompt` が公開されていないため、`--prompt` 指定時は内部で whisper-cli バイナリを直接呼び出す。

### `--postprocess` で利用可能なステップ

文字起こし結果（segments）に対して後処理を適用。複数指定はカンマ区切り（例: `--postprocess dedupe,fillers,paragraphs`）:

| ステップ | 効果 | 副作用 / 注意 |
|---|---|---|
| `dedupe` | 連続する重複セグメントを集約 | Whisper の繰り返し幻覚を抑制。実際に同じ発言を繰り返した場合も1つにまとめる点に注意 |
| `fillers` | フィラー語（「えー」「あのー」「um」等）を除去 | 言語に応じて辞書を切り替え。発言意図が変わる可能性が低い場面のみ推奨。インタビュー等の言い淀みが意味を持つケースでは off 推奨 |
| `paragraphs` | セグメント間に `--paragraph-gap` 秒以上の無音があれば段落区切りを入れる | md 出力で段落間に空行が挿入され、Claude が文脈を捉えやすくなる |

フィラー辞書を編集したい場合は `src/postprocessor.ts` の `FILLERS_JA` / `FILLERS_EN` を編集する。

## サポートモデル一覧

| モデル | サイズ | RAM | 速度 (M1 CPU) | 多言語 | 日本語 | 用途 |
|---|---|---|---|---|---|---|
| `tiny` | ~75MB | ~390MB | ~32x rt | ✓ | × | プレビュー・低スペック検証 |
| `tiny.en` | ~75MB | ~390MB | ~32x rt | — (英語専用) | — | 英語のリアルタイム実験 |
| `base` (デフォルト) | ~142MB | ~500MB | ~16x rt | ✓ | △ | 軽量・標準・英語実用 |
| `base.en` | ~142MB | ~500MB | ~16x rt | — | — | 英語の現実的バランス |
| `small` | ~466MB | ~1GB | ~6x rt | ✓ | ○ | 日本語の実用最小ライン |
| `small.en` | ~466MB | ~1GB | ~6x rt | — | — | 英語業務用 |
| `medium` | ~1.5GB | ~2.6GB | ~2x rt | ✓ | ◎ | 日本語高精度本番運用 |
| `medium.en` | ~1.5GB | ~2.6GB | ~2x rt | — | — | 英語高精度 |
| `large-v1` | ~3GB | ~4.7GB | ~1x rt | ✓ | ○ | 後方互換用（v2/v3未満） |
| `large` | ~3GB | ~4.7GB | ~1x rt | ✓ | ◎ | 最高精度（v3相当） |
| `large-v3-turbo` | ~1.6GB | ~2.5GB | ~8x rt | ✓ | ◎ | **迷ったらこれ** |

> **速度の読み方**: `16x rt` = 音声長の 1/16 の時間で処理（1時間音声を約 3.75分）。M1 CPU 目安。

### 各モデルの詳細・メリデメ

#### `tiny` / `tiny.en`
- **メリット**: 起動・推論が爆速、低スペックマシンでも動く。`.en` は英語専用で同サイズで精度向上。
- **デメリット**: 多言語版は誤認識が多く日本語はほぼ実用不可。複雑な会話・専門用語に弱い。
- **こういう時**: 音声がきれいで内容のあたりだけ知りたい、リアルタイム書き起こしのプロトタイプ。

#### `base` / `base.en`
- **メリット**: 軽量・高速・初回セットアップに優しい。2時間音声を 7〜10分で処理（M1）。英語なら一定精度。
- **デメリット**: 日本語精度は限定的、固有名詞や専門用語は誤りがち。雑音や複数話者に弱い。
- **こういう時**: とりあえず動かしたい、英語のミーティング録音。

#### `small` / `small.en`
- **メリット**: 日本語でも実用的な精度に届く最小ライン。サイズと精度のバランスが良い。M1 で 2時間 ≈ 20分。
- **デメリット**: medium / large に比べると専門用語の誤認識は残る。RAM 1GB を消費。
- **こういう時**: 日本語の打ち合わせを実用レベルで文字起こししたい時の最小選択。

#### `medium` / `medium.en`
- **メリット**: 多言語で高精度、固有名詞も拾いやすい。長尺会話でも安定したセグメント分割。
- **デメリット**: ~1.5GB と大きく初回 DL が重い。M1 で 2時間 ≈ 1〜1.5時間かかる。RAM 2.6GB 必要。
- **こういう時**: 日本語の本番運用、会議議事録、インタビュー書き起こし。

#### `large-v1`
- **メリット**: large 系の元祖モデル。再現性検証用。
- **デメリット**: v2/v3 に比べ精度が劣る。サイズ・推論時間は最新と同等で旨味が薄い。
- **こういう時**: 過去ワークフローとの整合性確認。新規プロジェクトで選ぶ理由はほぼ無し。

#### `large` (= large-v3 相当)
- **メリット**: 現行で最も高精度の多言語モデル。ノイズ・訛り・専門用語に強く、話者交代も比較的安定。
- **デメリット**: ~3GB / RAM ~4.7GB と重い。M1 CPU だと 2時間 ≈ 2〜3時間以上。GPU 推奨。
- **こういう時**: 精度最優先で時間に余裕がある業務用書き起こし。

#### `large-v3-turbo` ★ 推奨
- **メリット**: large-v3 にほぼ匹敵する精度を保ちつつ大幅高速化（M1 で 2時間 ≈ 15〜20分）。サイズ・RAM も medium 級まで削減。2026年現在のベストバランス。
- **デメリット**: ごく一部のドメイン（音楽、極端な訛り）で large-v3 にわずかに劣る。情報がやや少ない。
- **こういう時**: **迷ったらこれ**。日本語の長尺会話を高精度かつ現実的な時間で処理したい時。

### 選び方フローチャート

```
英語のみ？
├─ Yes → 速度優先: tiny.en / base.en
│        精度優先: small.en / medium.en
└─ No (日本語含む)
   ├─ プレビューしたいだけ          → tiny / base
   ├─ 実用レベルで速くしたい         → small
   ├─ 高精度な議事録、十分に時間あり    → medium
   └─ 高精度かつ現実的時間で          → large-v3-turbo  ★
```

## Markdown 出力の構造

```markdown
---
title: "..."
source: "..."
language: ja
duration_sec: 7245
duration_hms: 02:00:45
segment_count: 432
generated_at: 2026-05-08T...
---

# Title

## Metadata
...

## Summary Hooks
<!-- Claude にここを埋めさせる -->
- 要点 (3-5項目):
- 登場人物 / 話者:
- キーワード:
- 意思決定 / アクションアイテム:
- 未解決の論点:

## Transcript
- `[00:00:00]` こんにちは、本日は ...
- `[00:00:08]` ...
```

`Transcript` セクションを Claude に読み込ませ、`Summary Hooks` と任意の知識マップ（Mermaid 等）を生成させると効率的。

## Claude Code スキル: 知識ベース構築ワークフロー

`.claude/skills/voice-to-knowledge/` に、音声から知識ベースを構築する一連のワークフローを Claude Code スキルとして同梱している。

### ワークフロー（二層ナレッジ構造）

```
[workspace/inbox/foo.m4a]
    ↓ audio2text で文字起こし（前処理 + Whisper + 後処理）
[workspace/transcripts/foo.md]
    ↓ Claude がカテゴリ別テンプレでソースノートを生成
[workspace/knowledge/sources/<category>/YYYY-MM-DD_<slug>.md]   ← 第1層: 1音声=1ファイル
    ↓ アトミック抽出（decisions/tasks/facts/ideas/insights/questions/concepts）
[workspace/knowledge/<type>/YYYY-MM-DD_*.md]                    ← 第2層: 横断検索の原子
    ↓ ソースノートにリンク記入後、自動でアーカイブ
[workspace/archive/audio/foo.m4a]
[workspace/archive/transcripts/foo.md]
```

### 使い方

1. プロジェクトをビルドしておく:
   ```bash
   npm install && npm run build
   ```
2. 音声ファイルを `workspace/inbox/` に置く
3. Claude Code でこのリポジトリを開いた状態で、以下のように指示する:
   - 「voice-to-knowledge を実行して」
   - 「inbox の音声をナレッジ化して」
   - 「workspace/inbox の音声を全部処理して archive に移して」

Claude が `voice-to-knowledge` スキルを呼び出し、以下を実行する:
- 音声ファイルを列挙
- `audio2text` CLI で文字起こし（既定モデル: `large-v3-turbo`）
- transcript の内容から要約・カテゴリ分類してナレッジ化
- 完了ファイルをアーカイブに移動
- 結果サマリを報告

### 第1層: カテゴリ別ソースノート

音声の種類に応じてソースノートのカテゴリディレクトリと専用テンプレートが選ばれる:

| カテゴリ | 想定シーン | テンプレート |
|---|---|---|
| `business-meeting` | 仕事の会議・打ち合わせ | 議事録形式（決定・アクション重視） |
| `business-chat` | 1on1・雑談・廊下会話 | 業務手がかり拾い上げ形式 |
| `monologue` | 独り言・思考メモ | 思考の流れと未解決の問い |
| `private-chat` | 友人・家族との会話 | 出来事・人物・関係性メモ |
| `interview` | インタビュー | Q&A 構造＋引用重視 |
| `lecture` | 講演・プレゼン・教材 | 章立て＋定義集＋復習事項 |
| `general` | 上記に該当しない | 標準汎用テンプレート |

各テンプレートは `.claude/skills/voice-to-knowledge/templates/<category>.md` に独立配置。

### 第2層: アトミックノート（type別）

ソースノートから知識の原子を抽出し、以下の type 別ディレクトリに保存:

| type | 格納するもの | 専用テンプレート |
|---|---|---|
| `decisions/` | 決定・合意・約束 | `templates/atomic/decision.md` |
| `tasks/` | アクションアイテム・TODO | `templates/atomic/task.md` |
| `facts/` | 事実・技術知識・再利用可能情報 | `templates/atomic/fact.md` |
| `ideas/` | アイデア・仮説（採否未定） | `templates/atomic/idea.md` |
| `insights/` | 学び・気付き・教訓 | `templates/atomic/insight.md` |
| `questions/` | 未解決の問い | `templates/atomic/question.md` |
| `concepts/` | 用語定義・概念整理 | `templates/atomic/concept.md` |

**粒度ルール**: 1ノート = 1テーマ。タイトルが完結文。すべて `source:` でソースノートにバックリンク。
詳細は `.claude/skills/voice-to-knowledge/templates/atomic/README.md` 参照。

### ナレッジファイルの構造

frontmatter にメタデータ（録音日、カテゴリ、タグ等）、本文に以下のセクションを生成:

- 概要 (TL;DR)
- 主要トピック
- 重要なポイント / 知見
- 登場人物 / 話者
- 意思決定 / アクションアイテム
- 未解決の論点
- キーワード（検索用）
- 引用（タイムスタンプ付き）
- 関連ナレッジ（他ファイルへのリンク）

詳細は `.claude/skills/voice-to-knowledge/SKILL.md` を参照。

### スキルのカスタマイズ

カスタマイズの粒度は3層に分かれている:

| 変えたいもの | 編集場所 |
|---|---|
| 文字起こしのモデル/前処理/後処理/Whisper プロンプト | `.claude/skills/voice-to-knowledge/presets.json` |
| ソースノートの構造（カテゴリ別） | `.claude/skills/voice-to-knowledge/templates/<category>.md` |
| アトミックノートの構造（type別） | `.claude/skills/voice-to-knowledge/templates/atomic/<type>.md` |
| カテゴリ判定・抽出ルール・ワークフロー全体 | `.claude/skills/voice-to-knowledge/SKILL.md` |
| 録音ごとの個別プロンプト | `inbox/<filename>.prompt.txt` (sidecar) |
| 録音ごとのプリセット強制 | `inbox/<filename>.preset` (中身にプリセット名を1行) |

**新しいテンプレートを追加する**: `templates/my-pattern.md` として配置し、`presets.json` で `summary-template: "my-pattern.md"` と参照させる。

**新しいプリセットを追加する**: `presets.json` に新しいキーを追加。`category` と `summary-template` を含める。

### 既定モデルを変える

スキル実行時に「model=small で」のように伝えれば任意のモデルで処理できる。常用モデルを変えたい場合は `SKILL.md` 内の `--model large-v3-turbo` を書き換える。

## トラブルシューティング

- **`make` エラー / ネイティブビルド失敗** — C++ ビルドツールが必要。macOS: `xcode-select --install`、Ubuntu: `sudo apt install build-essential`。
- **モデルダウンロード失敗** — ネットワーク接続を確認、または手動: `npx nodejs-whisper download`
- **日本語の精度が低い** — `--model small` 以上を使用。`--model large-v3-turbo` 推奨。
- **メモリ不足** — モデルを下げる（large → medium → small）。
- **`--language ja` が反映されない** — 仕様。`nodejs-whisper@0.3.0` は言語指定APIを公開していないため自動検出に依存。出力の言語表示にのみ使用。

## 推測実装

不足情報の取り扱いは `ASSUMPTIONS.md` を参照。
