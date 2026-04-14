# ARCHITECTURE

## Frontends

- SwiftUI desktop app: `Sources/YTToolsApp/`
- Go TUI app: `cmd/yttools-tui/`

Both frontends share the same runtime strategy: build a `yt-dlp` command, optionally pass `ffmpeg` location, stream logs, and surface exit status.

## Swift app architecture

- `ContentView`
  - Presents job form, auth config, and logs.
- `MainViewModel`
  - Validates inputs.
  - Locates tooling.
  - Builds yt-dlp command arguments.
  - Launches process and streams output.
- `ProcessExecutor`
  - Runs shell process asynchronously.
  - Multiplexes stdout/stderr into one stream.
- `ToolLocator`
  - Resolves `yt-dlp` and `ffmpeg` from known paths + PATH.

## Go TUI architecture

- `model` in `cmd/yttools-tui/main.go`
  - Built with Bubble Tea + Huh + Lip Gloss + Bubbles viewport.
  - Holds form controls and process state.
  - Supports single URL or URL-list-file input mode.
  - Builds yt-dlp args for mode/auth combinations.
  - Starts/stops process and streams logs in terminal.
  - Opens browser login page for auth bootstrap.
  - Parses transfer speed from yt-dlp output and renders a live smoothed/animated throughput graph.

## Execution model

1. User submits one job.
2. Frontend builds argument list.
3. `yt-dlp` starts (with ffmpeg path if present).
4. Stdout/stderr stream into logs.
5. Exit status updates UI.

## Planned architecture expansion

- Shared `JobQueue` service shape (queue/retry/cancel)
- `ProfileStore` (saved presets)
- `HistoryStore` (completed jobs and metadata)
- `SubscriptionSyncService` (channel/playlist polling)
