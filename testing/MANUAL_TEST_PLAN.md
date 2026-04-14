# MANUAL TEST PLAN

## Preconditions

- `yt-dlp` installed and callable
- `ffmpeg` installed and callable
- app launches with `swift run yt-tools`

## Core test matrix

1. Audio extract (no auth)
- Input a public video URL
- Mode: Extract Audio Track
- Expected: audio-only output in chosen directory

2. Audio convert (mp3)
- Mode: Convert to Audio
- Audio: MP3
- Expected: converted MP3 file exists and plays

3. Video convert (mp4)
- Mode: Convert Video Format
- Video: MP4
- Expected: converted MP4 file exists and plays

4. Browser cookies auth
- Mode: any
- Auth: Use Browser Cookies (Safari/Chrome)
- Use a restricted video
- Expected: successful fetch if cookie extraction works

5. cookies.txt auth
- Mode: any
- Auth: Use cookies.txt
- Select valid cookie file
- Expected: successful fetch for restricted source

6. Cancellation
- Start long download, click Cancel
- Expected: process terminates and status changes from Running

## Failure checks

- Invalid URL should not start job
- Missing cookie path in file-cookie mode should raise error
- Missing ffmpeg should still allow non-conversion flows
