#!/usr/bin/env bash
# 音声ファイルと対応する transcript .md をアーカイブに移動する。
# 使い方: archive-pair.sh <audio-path> <transcript-md-path> [workspace-dir]
set -euo pipefail

AUDIO="${1:-}"
TRANSCRIPT="${2:-}"
WS="${3:-workspace}"

if [[ -z "$AUDIO" || -z "$TRANSCRIPT" ]]; then
  echo "Usage: archive-pair.sh <audio-path> <transcript-md-path> [workspace-dir]" >&2
  exit 1
fi

mkdir -p "$WS/archive/audio" "$WS/archive/transcripts"

if [[ -f "$AUDIO" ]]; then
  mv "$AUDIO" "$WS/archive/audio/"
  echo "Archived audio: $(basename "$AUDIO") -> $WS/archive/audio/"
else
  echo "WARN: audio file not found: $AUDIO" >&2
fi

if [[ -f "$TRANSCRIPT" ]]; then
  mv "$TRANSCRIPT" "$WS/archive/transcripts/"
  echo "Archived transcript: $(basename "$TRANSCRIPT") -> $WS/archive/transcripts/"
else
  echo "WARN: transcript file not found: $TRANSCRIPT" >&2
fi
