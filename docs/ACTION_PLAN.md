# ACTION PLAN

## Goal

Ship a stable macOS MVP that reliably downloads and converts YouTube media via `yt-dlp` + `ffmpeg`, then expand into playlist and subscription workflows.

## Phase 0: Foundation (Complete)

- Scaffold project structure
- Create macOS SwiftUI shell
- Create Go TUI shell
- Wire yt-dlp execution pipeline
- Add conversion and auth options
- Add dashboard and roadmap docs

## Phase 1: MVP Hardening (1-2 weeks)

1. Reliability
- Add strict URL + option validation
- Add clearer error mapping for common yt-dlp failures
- Add tool version checks in doctor script

2. UX
- Persist user preferences
- Improve progress parsing and status indicators
- Save recent output folders and recent URLs

3. Quality
- Unit tests for command argument generation
- Manual test matrix for auth + format combinations
- Crash-safe process cancellation flow

## Phase 2: Batch Workflows (2-3 weeks)

1. Queue engine
- Introduce job queue and worker state machine
- Add batch import (multiple URLs)

2. Playlist support
- Probe playlist metadata first
- Let user choose full vs selective items
- Track per-item success/failure

3. Recovery
- Add retry/backoff controls
- Add exportable job report

## Phase 3: Subscription Operations (4+ weeks)

1. Subscription model
- Persist subscribed channels/playlists
- Poll and diff new items

2. Automation
- Scheduled checks and auto-download rules
- Custom destination/format per subscription

3. Management
- Bulk actions (re-run, move, convert, cleanup)
- Search/filter dashboard for large libraries

## Risks

- Browser-cookie extraction differs by browser/macOS permissions
- YouTube behavior changes can impact yt-dlp extraction
- Format conversion can fail for edge codec combinations

## Mitigation

- Keep auth fallbacks (browser or cookies file)
- Log full command and stderr for supportability
- Offer conservative defaults (mp3/mp4) and clear warnings
