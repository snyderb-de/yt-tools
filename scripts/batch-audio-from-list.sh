#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "Usage: $0 <url_list_file> [output_dir]"
  echo "Example: $0 ~/Desktop/raelynn-list.text ~/Downloads/YTAudio"
  exit 1
fi

URL_FILE="$1"
OUTPUT_DIR="${2:-$HOME/Downloads/YTToolsAudio}"

if [[ ! -f "$URL_FILE" ]]; then
  echo "ERROR: URL list file not found: $URL_FILE"
  exit 1
fi

if ! command -v yt-dlp >/dev/null 2>&1; then
  echo "ERROR: yt-dlp is not installed. Run: brew install yt-dlp"
  exit 1
fi

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "ERROR: ffmpeg is not installed. Run: brew install ffmpeg"
  exit 1
fi

JS_RUNTIME_ARGS=()
if command -v node >/dev/null 2>&1; then
  JS_RUNTIME_ARGS=(--js-runtimes node)
else
  echo "WARN: node not found. Some YouTube videos may fail without JS runtime."
fi

mkdir -p "$OUTPUT_DIR"

echo "Reading URLs from: $URL_FILE"
echo "Saving MP3 files to: $OUTPUT_DIR"

total=0
success=0
failed=0

while IFS= read -r line || [[ -n "$line" ]]; do
  url="$(printf '%s' "$line" | sed 's/^\s*//;s/\s*$//')"

  if [[ -z "$url" || "$url" =~ ^# ]]; then
    continue
  fi

  total=$((total + 1))
  echo ""
  echo "[$total] Processing: $url"

  if yt-dlp \
    --no-playlist \
    "${JS_RUNTIME_ARGS[@]}" \
    -f "bestaudio/best" \
    -x \
    --audio-format mp3 \
    --audio-quality 0 \
    -P "$OUTPUT_DIR" \
    -o "%(title)s.%(ext)s" \
    "$url"; then
    success=$((success + 1))
  else
    failed=$((failed + 1))
    echo "WARN: Failed: $url"
  fi

done < "$URL_FILE"

echo ""
echo "Done. Total: $total, Success: $success, Failed: $failed"

if [[ "$failed" -gt 0 ]]; then
  exit 2
fi
