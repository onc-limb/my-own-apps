---
name: voice-to-knowledge
description: workspace/inbox/ にある音声ファイルを文字起こし→要約・分類して 1ファイル完結のナレッジファイルとして生成→処理済みファイルをアーカイブに移動する一連のワークフローを実行する。会議録音やインタビュー音声から知識ベースを構築したい時に使う。
---

# voice-to-knowledge

音声ファイルから 1ファイル完結のナレッジ（ソースノート）を生成するワークフロースキル。

## 概要

`workspace/inbox/` に置かれた音声ファイルを順番に処理し、最終的に **1音声 = 1ファイル** のナレッジを `workspace/knowledge/sources/<YYYY-MM>/` 月別ディレクトリに生成する。処理済みファイルは `workspace/archive/` に移動する。

```
[workspace/inbox/foo.m4a (+ optional foo.prompt.txt / foo.preset)]
    │ 1. プリセット解決 + sidecar 読み込み
    │ 2. audio2text で前処理 + 文字起こし + 後処理
    ▼
[workspace/transcripts/foo.md]   ← Whisper 出力
    │ 3. ソースノート生成（要約 + 各セクションを 1ファイルで）
    ▼
[workspace/knowledge/sources/<YYYY-MM>/YYYY-MM-DD_<slug>.md]
    │ 4. 元ファイルをアーカイブ
    ▼
[workspace/archive/audio/foo.m4a]
[workspace/archive/transcripts/foo.md]
```

生成されたソースファイルは `omni-archive` (`/Users/satoshi-onga/Documents/onclimb-industries/projects/omni-archive`) の inbox に **手動で** 取り込む運用とする。本スキルは生成までを担当し、その先のコピー・分割は受け持たない。

## ナレッジファイルの構造（1ファイル完結）

```
workspace/knowledge/
└── sources/
    ├── 2026-05/
    │   ├── 2026-05-08_foobar-mtg.md
    │   └── 2026-05-12_xxx.md
    ├── 2026-06/
    │   └── ...
    └── ...
```

- 1音声 = 1ファイル
- ファイル内に要約と各セクション（決定 / タスク / アイデア / 学び / 知識・事実 / 問い / 用語）を持つ
- 月別ディレクトリ（`YYYY-MM/`）配下に平置き
- カテゴリ分類は frontmatter の `category` フィールドで保持（ディレクトリでは分けない）

## ファイル構造（必須セクションと任意セクション）

すべてのソースノートは以下の構造を持つ:

| セクション | 必須/任意 | 内容 |
|---|---|---|
| frontmatter | 必須 | title, source_audio, recorded_at, category, preset, language, duration, participants, tags 等 |
| `# <Title>` | 必須 | タイトル見出し |
| `## 要約 (TL;DR)` | **必須** | 2〜5文で「何の話で、何が分かったか」 |
| `## 話題の流れ` | 任意 | 議題・トピック単位の要点 |
| `## 決定事項` | 任意 | 合意・決定された事項 |
| `## タスク` | 任意 | 行動可能項目（担当・期日があれば併記） |
| `## アイデア` | 任意 | 採否未定の発想・仮説 |
| `## 学び・気付き` | 任意 | 主観的気付き、教訓、メタ認知 |
| `## 知識・事実` | 任意 | 客観的な事実・数値・仕様 |
| `## 未解決の問い` | 任意 | 答えが出なかった論点、要調査 |
| `## 用語・概念` | 任意 | 会話中に定義された用語 |
| `## キーワード` | 任意 | バッククォート区切りのキーワード列 |
| `## 引用 / 印象に残った発言` | 任意 | タイムスタンプ付きの発言抜粋 |
| `## 関連` | 任意 | 関連する別のソースノートへの参照 |

任意セクションは該当する内容がない場合 **見出しごと省略** する（プレースホルダーは残さない）。

## カスタマイズポイント

ユーザーは以下を編集することで挙動を調整できる:

| カスタマイズ対象 | 場所 |
|---|---|
| 文字起こしのモデル/前処理/後処理/Whisper プロンプト/VAD | `presets.json` |
| ソースノートの構造（カテゴリ別） | `templates/<category>.md` |
| カテゴリ分類のルール | この `SKILL.md` の Step 6-1 セクション |
| 録音ごとの個別プロンプト | `inbox/<filename>.prompt.txt` (sidecar) |
| 録音ごとのプリセット強制 | `inbox/<filename>.preset` (中身にプリセット名を1行) |
| フィラー語の追加・除去 | `audio2text/src/postprocessor.ts` の `FILLERS_JA / FILLERS_EN` |

## カテゴリとテンプレート対応

| カテゴリ | 想定シーン | プリセット | テンプレート |
|---|---|---|---|
| `business-meeting` | 仕事の会議・打ち合わせ | `business-meeting` | `business-meeting.md` |
| `business-chat` | 仕事関連の雑談・1on1 | `business-chat` | `business-chat.md` |
| `monologue` | 独り言・思考メモ・運転中録音 | `monologue` | `monologue.md` |
| `private-chat` | 友人・家族とのプライベート会話 | `private-chat` | `private-chat.md` |
| `interview` | インタビュー・対話形式 | `interview` | `interview.md` |
| `lecture` | 講演・プレゼン・教材 | `lecture` | `lecture.md` |
| `general` | 上記に該当しない | `default` | `general.md` |

## 実行手順

### 前提チェック

スキル実行前に以下を確認する:

1. プロジェクトがビルド済みか — `dist/index.js` が存在するか確認。なければ `npm install && npm run build`
2. workspace ディレクトリ構造の確認 — 不足していれば `bash .claude/skills/voice-to-knowledge/scripts/init-workspace.sh`
3. inbox に処理対象があるか — `bash .claude/skills/voice-to-knowledge/scripts/list-inbox.sh`

### Step 1: inbox のスキャン

```bash
bash .claude/skills/voice-to-knowledge/scripts/list-inbox.sh workspace/inbox
```

対応形式: `.mp3 / .m4a / .wav / .mp4 / .webm / .ogg / .flac / .aac`

ファイルが0件ならユーザーに「inbox に音声ファイルがありません」と伝えて終了する。

### Step 2: プリセット解決

`presets.json` を Read で読み、以下の優先順位でプリセットを決定する:

1. **ユーザーがスキル実行時に `preset=xxx` を指定した場合** → そのプリセットを使う
2. **inbox に `<filename>.preset` ファイルがある場合** → 中身に書かれたプリセット名を使う
3. **それ以外** → ファイル名のヒントから推定:
   - `meeting`, `mtg`, `打ち合わせ` を含む → `business-meeting`
   - `1on1`, `chat`, `雑談` を含む → `business-chat`
   - `memo`, `note`, `独り言`, `思考` を含む → `monologue`
   - `family`, `friend`, `private` を含む → `private-chat`
   - `interview`, `インタビュー` を含む → `interview`
   - `lecture`, `講演`, `prez` を含む → `lecture`
   - 不明 → ユーザーに確認するか `default`
4. **判断がつかない場合** → ユーザーに確認するか `default` を使う

プリセットから取り出すフィールド:
- `model`, `preprocess`, `postprocess`, `paragraph-gap`, `segment-length`, `language`, `prompt-style`, `vad`, `vad-threshold`, `summary-template`, `category`

### Step 3: 録音ごとの prompt 合成

**原則**: プロンプトは固有名詞・専門用語が事前に分かっている場合の **sidecar 経由のみ** で渡す。プリセット側の `prompt-style` は基本的に空（誘導文をプロンプトに固定すると、無音・環境音区間で幻聴ループの種になる）。

最終的な Whisper の `--prompt` の中身は以下を結合して構成する:

1. プリセットの `prompt-style`（通常は空。明示的に短い誘導文が入っている場合のみ採用）
2. **`inbox/<filename>.prompt.txt` の中身**（sidecar、固有名詞や文脈情報。これがメインの prompt 注入経路）

sidecar 例（業務会議用、固有名詞だけ列挙）:
```
参加者: 山田、佐藤、田中
プロダクト名: Foobar API、Acme SDK
専門用語: KPI、ARR、CAC、LTV
```

sidecar も `prompt-style` も無ければ、`--prompt-file` 自体を渡さずに実行する（プロンプトなし）。

### Step 4: 文字起こし

```bash
node dist/index.js "workspace/inbox/<filename>" \
  --model <preset.model> \
  --language <preset.language> \
  --segment-length <preset.segment-length> \
  [--preprocess <preset.preprocess (joined by comma)>] \
  --postprocess <preset.postprocess (joined by comma)> \
  --paragraph-gap <preset.paragraph-gap> \
  [--vad --vad-threshold <preset.vad-threshold>] \
  [--prompt-file <一時ファイル>] \
  --format md \
  --output "workspace/transcripts/<stem>.md" \
  --title "<filename without extension>"
```

**フラグの組み立てルール**:
- `preset.preprocess` が空配列の場合は `--preprocess` を渡さない
- `preset.vad === true` の場合 `--vad` を追加。`preset.vad-threshold` があれば `--vad-threshold <値>` も追加
- 合成プロンプトが空文字列の場合は `--prompt-file` を渡さない
- 合成プロンプトが非空の場合のみ一時ファイルに書いて `--prompt-file` で渡す（シェルエスケープ事故防止）

**注意**:
- VAD は preprocess の `silence-trim` と機能重複する。両方使うと過剰圧縮で幻聴の種になる。プリセットでは `silence-trim` を外し、VAD に寄せている
- `normalize` も VAD と相性が悪く、全プリセットで除外している（normalize で増幅された結果 VAD が幻聴区間を発話と誤検出する）
- 失敗した場合は記録して次のファイルへ進む（途中で全体を止めない）

### Step 5: 文字起こし結果の読み込み

`Read` ツールで `workspace/transcripts/<stem>.md` の内容を読む。

frontmatter から `language`, `duration_hms`, `segment_count` を取得しておく。

### Step 6: ソースノートを 1ファイルで生成

「この音声全体は何だったか」を要約しつつ、決定 / タスク / アイデア / 学び / 知識・事実 / 問い / 用語 を **同じファイル内のセクション** として記入する。

#### Step 6-1: カテゴリ判定（プリセットに `category` があれば優先）

プリセットに `category` があればそれを採用。`default` プリセットの場合や曖昧な場合は、文字起こし内容から推定する:

| 判定基準 | 候補カテゴリ |
|---|---|
| 複数話者・議題・敬語が多い・決定が出る | `business-meeting` |
| 複数話者・カジュアル・業務関連の話題 | `business-chat` |
| 1人の話者・独白的・思考が飛ぶ | `monologue` |
| 複数話者・プライベートな話題（家族・趣味・出来事） | `private-chat` |
| 質問→回答が明確に交互 | `interview` |
| 1人の話者・章立て・教材的 | `lecture` |
| 上記いずれにも明確に該当しない | `general` |

複数候補がある場合は最も多くの基準を満たすものを採用。それでも迷う場合は `general` にフォールバック。

#### Step 6-2: テンプレート読み込み

`category` に対応するテンプレートを Read で読む:

```
.claude/skills/voice-to-knowledge/templates/<template-file>
```

例: `business-meeting` カテゴリなら `templates/business-meeting.md` を読み込む。

`presets.json` の `summary-template` フィールドが指定されていればそれを優先。

#### Step 6-3: テンプレートに従って本文を生成

読み込んだテンプレートの:
- **「抽出時の基本方針」** を行動指針として遵守
- **「出力フォーマット」** の構造をそのまま採用
- **「注意」** に書かれた制約を守る

の3点を厳守する。テンプレートに無いセクションを勝手に追加しない。**該当する内容が無いセクションは見出しごと省略する**（プレースホルダーは残さない）。

ただし `## 要約 (TL;DR)` は **必ず記入する**（必須セクション）。

#### Step 6-4: ファイル名

`YYYY-MM-DD_<slug>.md` 形式
- `YYYY-MM-DD`: 録音日が文字起こしに明示されていればそれを使用、無ければ今日の日付
- `<slug>`: タイトルから生成。日本語可・英数字とハイフンのみ。30文字以内
- 同日重複時: 末尾に `-2`, `-3`

#### Step 6-5: 保存先

`workspace/knowledge/sources/<YYYY-MM>/<filename>`

- 月別ディレクトリ `<YYYY-MM>/` が無ければ作成する（例: `2026-05/`）
- カテゴリ別のサブディレクトリは作らない（カテゴリは frontmatter で保持）

### Step 7: アーカイブ移動

ナレッジファイルが正しく生成されたことを確認した上で、元の音声と中間 transcript を archive に移動:

```bash
bash .claude/skills/voice-to-knowledge/scripts/archive-pair.sh \
  "workspace/inbox/<filename>" \
  "workspace/transcripts/<stem>.md"
```

sidecar ファイル (`<filename>.prompt.txt`, `<filename>.preset`) も一緒にアーカイブに移動する:

```bash
mv workspace/inbox/<filename>.prompt.txt workspace/archive/audio/ 2>/dev/null || true
mv workspace/inbox/<filename>.preset workspace/archive/audio/ 2>/dev/null || true
```

**重要**: ナレッジ生成に失敗した場合はアーカイブ移動をスキップし、エラーを記録する。

### Step 8: 結果報告

すべての処理が終わったら、以下のサマリをユーザーに報告する:

```
## 処理結果

- 処理対象: N 件
- 成功: M 件
- 失敗: K 件

### 生成されたソースノート

- workspace/knowledge/sources/2026-05/2026-05-08_foobar-mtg.md (preset: business-meeting)
- workspace/knowledge/sources/2026-05/2026-05-12_yyy.md (preset: private-chat)

### 各ノートに含まれるセクション件数（参考）

| ファイル | 決定 | タスク | アイデア | 学び | 事実 | 問い | 用語 |
|---|---|---|---|---|---|---|---|
| 2026-05-08_foobar-mtg.md | 3 | 5 | 1 | 2 | 4 | 1 | 0 |

### 失敗したファイル

- foo.mp3 — エラー: ...

### 次のステップ（手動）

生成されたソースノートを omni-archive (/Users/satoshi-onga/Documents/onclimb-industries/projects/omni-archive) の inbox に取り込む場合は、人間がコピーする。
```

## 引数オプション（ユーザーが指定可能）

ユーザーがスキル起動時に以下を指定した場合、それに従う:

| キー | 例 | 意味 |
|---|---|---|
| `workspace=<path>` | `workspace=/Users/me/audio` | 既定の `workspace/` 以外を使う |
| `preset=<name>` | `preset=business-meeting` | 全ファイルにこのプリセットを強制 |
| `template=<file>` | `template=lecture.md` | 要約テンプレートだけ強制（プリセットの summary-template を上書き） |
| `model=<name>` | `model=small` | プリセットを上書きしてこのモデルに |
| `file=<name>` | `file=foo.m4a` | inbox 全走査ではなく指定ファイルのみ |
| `dry-run` | — | 実際の文字起こし・移動を行わず計画だけ報告 |

## 失敗時の挙動

- 文字起こしに失敗 → そのファイルはスキップ。inbox に残したままにする
- ナレッジ生成に失敗 → transcript は `workspace/transcripts/` に残す。アーカイブ移動はしない
- 1ファイルの失敗で全体を止めない（複数ファイル処理時）

## 注意事項

- 並行実行はしない（Whisper モデルが RAM 競合する）
- 2時間音声を `large-v3-turbo` で処理すると約 15〜20分かかる（M1 CPU 目安）。処理時間が長くなる旨を事前にユーザーに伝える
- 個人情報を含む可能性が高い音声を扱うため、外部に送信せず、すべてローカルで完結する
- prompt が改行を含む場合は一時ファイル経由で `--prompt-file` を使う（シェルエスケープ事故防止）
- private-chat / interview などプライバシー性の高いカテゴリでは、第三者情報の取り扱いに注意（テンプレートの「注意」セクションを参照）
- 生成したソースファイルを omni-archive に取り込むのは人間が手動で行う（本スキルのスコープ外）
