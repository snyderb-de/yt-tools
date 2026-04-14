#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="$ROOT_DIR/releases/macos"
BIN_NAME="yt-tools"

mkdir -p "$OUT_DIR"

echo "[build] running swift build (release)"
cd "$ROOT_DIR"
swift build -c release

BIN_PATH="$ROOT_DIR/.build/release/$BIN_NAME"
if [[ ! -f "$BIN_PATH" ]]; then
  echo "[build] binary not found: $BIN_PATH"
  exit 1
fi

cp "$BIN_PATH" "$OUT_DIR/$BIN_NAME"
echo "[build] copied binary -> $OUT_DIR/$BIN_NAME"
