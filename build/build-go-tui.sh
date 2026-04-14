#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="$ROOT_DIR/releases/macos"
BIN_NAME="yttools-tui"

mkdir -p "$OUT_DIR"

cd "$ROOT_DIR"
go build -o "$OUT_DIR/$BIN_NAME" ./cmd/yttools-tui

echo "[build] go tui binary -> $OUT_DIR/$BIN_NAME"
