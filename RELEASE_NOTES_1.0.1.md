# Lunarr Player 1.0.1

Lunarr Player 1.0.1 is a maintenance release for the feature-complete Windows
player. It fixes Discovery search encoding, completes Jellyfin subtitle
switching and hardens unencrypted Seerr connections.

## Bug fixes

- Multiword, Unicode and special-character searches now work reliably with
  TMDB and Seerr, including installations behind a reverse-proxy base path.
- Jellyfin subtitles can be changed from **Off** to a concrete track and back
  to **Off** during playback.
- The Jellyfin subtitle catalogue remains available while the active media
  source is unchanged, and stale track actions cannot affect a newer item.
- HTTP Seerr connections now require an explicit confirmation before the
  administrator API key is sent. The confirmation is tied to the normalized
  endpoint and is invalid after the endpoint changes.

## New Windows installer

The release is delivered as
`Lunarr-Player-1.0.1-windows-x64-setup.exe`. It contains the application,
MPV/libmpv, Flutter and required Windows runtime files. The installer lets you
choose a persistent destination, creates a Start menu shortcut and includes a
standard uninstaller. No ZIP extraction or separate runtime download is
needed.

The installer is not code-signed. Windows SmartScreen may therefore show a
warning. Verify the download with the accompanying `.sha256` file if desired.

Existing playlists, settings, favorites, playback progress and connection
profiles remain compatible.
