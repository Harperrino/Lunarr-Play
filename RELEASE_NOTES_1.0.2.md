# Lunarr Player 1.0.2

Lunarr Player 1.0.2 fixes category pinning, Jellyfin 12.1 connections and
programme-guide loading, and returns Windows distribution to a portable ZIP.

## Bug fixes

- Categories can be pinned and unpinned in playlist management and Live TV.
  Concurrent changes preserve the correct playlist's pins. VOD and series
  use the same corrected pinning flow.
- Jellyfin 12.1 connections use current authentication for login, libraries,
  playback, artwork and session reporting.
- Compressed XMLTV downloads are decoded once and stalled downloads time out.
- Returning to the channel list or updating a channel's metadata no longer
  leaves programme information waiting for another list change.
- Current programme titles advance with time without needing to scroll.

## Programme guide

- Select multiple playlists and categories independently of the Live TV sidebar
  and the playing channel. Filter lists can be searched and reset.
- Current and next programmes appear below the Live TV player with broadcast
  times and, when available, the current programme description.
- The channel list shows the current programme. Cached guide data remains
  visible during refresh, and loading failures offer a retry action.
- Programme matching preserves playlist ownership when sources reuse XMLTV IDs.

## Portable Windows distribution

Download `Lunarr-Player-1.0.2-windows-x64-portable.zip`, extract the complete
archive and run `lunarr_one.exe`. Keep the DLLs and `data/` directory beside it.
The ZIP bundles MPV/libmpv, Flutter, the Visual C++ runtime and license notices.
No installer or separate runtime download is required.

Existing playlists, settings, favorites, playback progress and connection
profiles remain in their existing per-user locations. Replace the complete
application folder when updating rather than copying only the executable.

The Windows build is not code-signed, so SmartScreen may show a warning. The
release includes a `.sha256` file for checking the portable ZIP.
