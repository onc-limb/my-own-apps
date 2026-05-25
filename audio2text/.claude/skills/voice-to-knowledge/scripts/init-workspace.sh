#!/usr/bin/env bash
# voice-to-knowledge ワークスペースのディレクトリ構造を初期化する。
# 使い方: init-workspace.sh [workspace-dir]
# - 引数省略時: ./workspace を使用
set -euo pipefail

WS="${1:-workspace}"

# 入出力ディレクトリ + ソースノート保管ディレクトリ
mkdir -p \
  "$WS/inbox" \
  "$WS/transcripts" \
  "$WS/archive/audio" \
  "$WS/archive/transcripts" \
  "$WS/knowledge/sources"

# .gitkeep を配置（ディレクトリ構造を git で追跡）
for d in \
  inbox \
  transcripts \
  archive/audio \
  archive/transcripts \
  knowledge/sources ; do
  touch "$WS/$d/.gitkeep"
done

echo "Workspace initialized at: $WS"
echo ""
echo "Structure:"
find "$WS" -type d -not -path "*/.*" | sort | sed "s|^$WS|workspace|"
echo ""
echo "Note: knowledge/sources/<YYYY-MM>/ は voice-to-knowledge 実行時に動的に作成されます。"
