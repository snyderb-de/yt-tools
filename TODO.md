# TODO

## MVP (Now)

- [x] Scaffold repo using skeleton structure
- [x] Build SwiftUI desktop shell with job form
- [x] Build Go TUI shell with equivalent job controls
- [x] Integrate `yt-dlp` process execution
- [x] Integrate `ffmpeg` conversion options through `yt-dlp` flags
- [x] Add auth passthrough modes (none/browser-cookies/cookies-file)
- [x] Add live log streaming + command preview
- [x] Add browser-login shortcut for cookie-based auth in TUI
- [x] Add URL-list-file mode in Swift app and Go TUI app
- [x] Add CLI batch script for URL list -> MP3 conversion
- [x] Migrate Go TUI to Charm stack (Bubble Tea + Huh + Lip Gloss)
- [x] Add live network throughput graph to Swift and Go frontends (smoothed + animated)
- [ ] Add input validation messaging improvements
- [ ] Add user preset save/load (format + output + auth)
- [ ] Add settings persistence (both frontends)

## Phase 2 (Near term)

- [ ] Multi-job queue (pause/resume/cancel)
- [ ] Playlist support with selective item inclusion
- [ ] Bulk URL import (paste list, drag-drop text file)
- [ ] Retry strategy + failed-item isolation
- [ ] Download history index and open-in-finder shortcuts

## Phase 3 (Long term)

- [ ] Subscription/channel management panel
- [ ] Background sync jobs
- [ ] Rule-based auto-download profiles
- [ ] Metadata tagging/renaming templates
- [ ] Release packaging (signed app bundle + DMG)

## Quality + Ops

- [ ] Add unit tests for command argument builders (Swift + Go)
- [ ] Add snapshot/manual test checklist per mode and auth path
- [ ] Add CI script for lint + build
- [ ] Add crash/error report capture path
