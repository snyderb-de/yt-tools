#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
./scripts/doctor.sh
go run ./cmd/yttools-tui
