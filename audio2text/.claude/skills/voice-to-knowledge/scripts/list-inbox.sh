#!/usr/bin/env bash
# 指定された inbox ディレクトリから対応形式の音声ファイルを列挙する。
# 使い方: list-inbox.sh [inbox-dir]
# - 引数省略時: ./workspace/inbox を使用
set -euo pipefail

INBOX="${1:-workspace/inbox}"

if [[ ! -d "$INBOX" ]]; then
  echo "ERROR: inbox directory not found: $INBOX" >&2
  exit 1
fi

# 対応する拡張子（小文字・大文字とも許容）
shopt -s nullglob nocaseglob
cd "$INBOX"
for f in *.mp3 *.m4a *.wav *.mp4 *.webm *.ogg *.flac *.aac; do
  echo "$f"
done
