#!/usr/bin/env bash
set -euo pipefail

echo "[doctor] checking toolchain"

missing=0

check_cmd() {
  local cmd="$1"
  if command -v "$cmd" >/dev/null 2>&1; then
    local resolved
    resolved="$(command -v "$cmd")"
    echo "[ok] $cmd -> $resolved"
  else
    echo "[missing] $cmd"
    missing=1
  fi
}

check_cmd swift
check_cmd go
check_cmd yt-dlp
check_cmd ffmpeg

if [[ "$missing" -ne 0 ]]; then
  echo ""
  echo "Install missing dependencies first."
  echo "Suggested: brew install yt-dlp ffmpeg"
  exit 1
fi

echo ""
echo "[doctor] versions"
swift --version | head -n 1
yt-dlp --version | head -n 1
ffmpeg -version | head -n 1

echo ""
echo "[doctor] all required tools are available"
