# INSTALL

## System requirements

- macOS 13+
- Xcode Command Line Tools (`xcode-select --install`) for Swift app
- Go 1.26+ for TUI app
- Homebrew

## Dependencies

```bash
brew install yt-dlp ffmpeg
```

Optional fallback browser:

```bash
brew install --cask firefox
```

## Setup

```bash
cd /Users/baghead/code/yt-tools
./scripts/doctor.sh
```

## Run SwiftUI app

```bash
swift build
swift run yt-tools
```

## Run Go TUI

```bash
go mod tidy
go run ./cmd/yttools-tui
```

## Run CLI batch from URL list

```bash
./scripts/batch-audio-from-list.sh ~/Desktop/raelynn-list.text
```

Optional output directory:

```bash
./scripts/batch-audio-from-list.sh ~/Desktop/raelynn-list.text ~/Downloads/YTAudio
```

## Authentication notes

Auth is delegated to `yt-dlp`.

- Browser cookies mode: `--cookies-from-browser <browser>`
- Cookies file mode: `--cookies /path/to/cookies.txt`

For browser auth in TUI, click `Open YouTube Login`, sign in, then run with `cookies-from-browser`.

## Troubleshooting

- `yt-dlp not found`: verify `PATH` and reinstall with Homebrew if needed.
- `ffmpeg missing`: conversion modes will fail until installed.
- Browser cookie extraction failure: switch to `cookies-file` mode.
