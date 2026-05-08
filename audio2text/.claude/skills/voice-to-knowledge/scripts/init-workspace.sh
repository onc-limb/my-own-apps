#!/usr/bin/env bash
# voice-to-knowledge ワークスペースのディレクトリ構造を初期化する。
# 使い方: init-workspace.sh [workspace-dir]
# - 引数省略時: ./workspace を使用
set -euo pipefail

WS="${1:-workspace}"

# 入出力ディレクトリ
mkdir -p \
  "$WS/inbox" \
  "$WS/transcripts" \
  "$WS/archive/audio" \
  "$WS/archive/transcripts"

# ナレッジベースの二層構造
# 第1層: ソースノート（カテゴリ別）
mkdir -p \
  "$WS/knowledge/sources/business-meeting" \
  "$WS/knowledge/sources/business-chat" \
  "$WS/knowledge/sources/monologue" \
  "$WS/knowledge/sources/private-chat" \
  "$WS/knowledge/sources/interview" \
  "$WS/knowledge/sources/lecture" \
  "$WS/knowledge/sources/general"

# 第2層: 抽出されたアトミックノート（type 別）
mkdir -p \
  "$WS/knowledge/decisions" \
  "$WS/knowledge/tasks" \
  "$WS/knowledge/facts" \
  "$WS/knowledge/ideas" \
  "$WS/knowledge/insights" \
  "$WS/knowledge/questions" \
  "$WS/knowledge/concepts"

# .gitkeep を配置（ディレクトリ構造を git で追跡）
for d in \
  inbox \
  transcripts \
  archive/audio \
  archive/transcripts \
  knowledge/sources \
  knowledge/sources/business-meeting \
  knowledge/sources/business-chat \
  knowledge/sources/monologue \
  knowledge/sources/private-chat \
  knowledge/sources/interview \
  knowledge/sources/lecture \
  knowledge/sources/general \
  knowledge/decisions \
  knowledge/tasks \
  knowledge/facts \
  knowledge/ideas \
  knowledge/insights \
  knowledge/questions \
  knowledge/concepts ; do
  touch "$WS/$d/.gitkeep"
done

echo "Workspace initialized at: $WS"
echo ""
echo "Structure:"
find "$WS" -type d -not -path "*/.*" | sort | sed "s|^$WS|workspace|"
