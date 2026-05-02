# yt-tools

YouTube downloader/converter toolkit with two frontends:

- macOS SwiftUI app
- Go terminal UI (TUI) built with Charm (`bubbletea` + `huh` + `lipgloss`)

Both run `yt-dlp` and `ffmpeg` locally.

## What the MVP supports

- Download from a YouTube URL
- Download from a URL list file (one URL per line)
- Modes:
  - Extract audio track
  - Convert to audio (`mp3`, `m4a`, `wav`, `flac`, `opus`)
  - Convert video (`mp4`, `mkv`, `webm`, `mov`)
- Output directory + filename template
- Auth via `yt-dlp`:
  - `--cookies-from-browser`
  - `--cookies /path/to/cookies.txt`
- Live job logs and cancel support
- Live network throughput graph in both frontends (animated gradient + smoothing)
- Input validation with actionable warnings/errors
- Saved presets (format/output/auth) in both frontends
- Persistent settings across launches in both frontends

## Repo layout

- `Sources/YTToolsApp/` - SwiftUI macOS app
- `cmd/yttools-tui/` - Go TUI app
- `scripts/batch-audio-from-list.sh` - CLI batch MP3 command for URL files
- `build/` - build scripts and artifacts
- `dashboard/` - project dashboard (HTML/CSS/JS)
- `docs/` - architecture + action plan
- `releases/` - release staging folders
- `scripts/` - local dev helpers
- `testing/` - manual QA docs

## Quick start

1. Install tools:
```bash
brew install yt-dlp ffmpeg
```

2. Validate environment:
```bash
./scripts/doctor.sh
```

3. Run either frontend:
```bash
swift run yt-tools
```

```bash
go run ./cmd/yttools-tui
```

Go TUI keys:
- `Ctrl+R` run
- `Ctrl+X` cancel
- `Ctrl+L` open YouTube login in browser
- `Ctrl+S` save preset
- `Ctrl+O` load preset
- `Q` quit (or `Ctrl+C` when idle)

4. Batch audio from URL list file:
```bash
./scripts/batch-audio-from-list.sh ~/Desktop/raelynn-list.text
```

## Build binaries

```bash
./build/build-macos.sh
```

```bash
./build/build-go-tui.sh
```

## MVP scope

- Single URL jobs
- One job at a time
- Local execution only

## Planned next scope

- Playlist workflows
- Subscription/channel management
- Bulk queue actions
- Automation rules

See `TODO.md` and `docs/ACTION_PLAN.md` for roadmap details.
