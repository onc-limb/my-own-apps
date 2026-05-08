# Workspace

`voice-to-knowledge` スキルが利用するワークスペース。

## ディレクトリ

| パス | 役割 |
|---|---|
| `inbox/` | 未処理の音声ファイルを置く |
| `transcripts/` | 文字起こし `.md`（中間生成物） |
| `knowledge/sources/<category>/` | **ソースノート**（1音声 = 1ファイル、サマリー兼インデックス） |
| `knowledge/decisions/` | アトミックノート: 決定事項・合意・約束 |
| `knowledge/tasks/` | アトミックノート: アクションアイテム・TODO |
| `knowledge/facts/` | アトミックノート: 事実・技術知識・再利用可能情報 |
| `knowledge/ideas/` | アトミックノート: アイデア・仮説（採否未定） |
| `knowledge/insights/` | アトミックノート: 学び・気付き・教訓 |
| `knowledge/questions/` | アトミックノート: 未解決の問い |
| `knowledge/concepts/` | アトミックノート: 用語定義・概念整理 |
| `archive/audio/` | 処理済み音声ファイル |
| `archive/transcripts/` | 処理済み文字起こし `.md` |

## 二層構造

```
[inbox/foo.m4a]
    ↓ audio2text
[transcripts/foo.md]
    ↓ Claude
[knowledge/sources/<category>/YYYY-MM-DD_foo.md]   ← 第1層: ソースノート（インデックス）
    ↓ アトミック抽出
[knowledge/<type>/YYYY-MM-DD_*.md]                 ← 第2層: アトミックノート（横断検索の単位）
    ↓ アーカイブ
[archive/audio/foo.m4a]
[archive/transcripts/foo.md]
```

**ソースノート**は会議全体のサマリーとアトミックノートへのリンク集。
**アトミックノート**は再利用可能な知識の原子。複数のソースから参照されうる。

## 検索のしかた（運用例）

- **「今週の決定事項一覧」** → `knowledge/decisions/` を見る、または `recorded_at: 2026-05-08...` で grep
- **「未着手のタスク」** → `knowledge/tasks/` で `status: pending` を grep
- **「JWT について何を知ってる？」** → `knowledge/facts/` と `knowledge/concepts/` を JWT で検索
- **「あの会議で何が決まった？」** → `knowledge/sources/business-meeting/` で該当ノートを開く
- **「山田さんが出てきた音声全部」** → 全ファイルで `people:` フィールドを横断検索

## Git 管理

- ディレクトリ構造（`.gitkeep`）のみコミット
- 中身（音声・文字起こし・ナレッジ）はすべて `.gitignore` で除外（プライバシー配慮）
