# Changelog

## 0.9.1 RC2

RC2 makes large libraries faster to browse, fixes playlist and programme-guide
mix-ups, and introduces the final Lunarr Player branding.

### Highlights

- Final layered moon logo and matching Lunarr Player wordmark in the app,
  Windows executable and GitHub project.
- Much faster switching between playlists after their first load.
- A responsive “All active playlists” view that combines enabled sources
  without hanging.
- Inactive playlists can be opened temporarily without silently enabling them.
- Alphabetical and numeric sorting no longer freezes the interface on very
  large channel lists.

### Programme guide

- Programme data is now kept separate for every playlist. Providers using the
  same channel IDs can no longer overwrite or display each other's schedule.
- The guide loads as one current snapshot, reducing repeated database work and
  stale results while switching playlists or time ranges.
- Short programmes retain their correct visual duration without overlapping
  the next programme.

### Imports and privacy

- Large M3U, Xtream and XMLTV imports now have safe resource limits,
  cancellation and atomic updates, so a rejected import cannot leave a
  half-replaced library.
- Diagnostics redact credentials, private URLs and local paths before they
  reach logs, the UI or copied reports.
- Error messages remain useful without exposing provider credentials.

### Interface and accessibility

- English UI text is now managed through a localization system, providing the
  foundation for additional languages.
- Narrow layouts, high contrast, reduced motion, keyboard focus and large text
  received additional regression coverage.
- Playlist selection, active status and the playlist-management screen now
  behave as separate, predictable controls.

### Updating

- Existing Beta 5 and RC1 playlists, settings, favorites and playback progress
  remain available.
- Replace the complete previous application folder with the contents of the
  new portable ZIP. Do not copy only the executable.
- The Windows build is not code-signed, so SmartScreen may show a warning.

## 0.9.0 RC1

LUNARR One introduces the final product identity for the current Windows release
candidate. The application now uses a neutral Material 3 moon-and-screen mark
as its Windows, iOS and macOS icon and displays the same mark beside a centered
LUNARR One wordmark in the desktop sidebar.

The release includes the responsive Material 3 redesign, favorites and Watch
Later libraries, pinned and hidden category management, improved VOD/series and
EPG experiences, high-contrast and reduced-motion modes, large-text layout
hardening, narrower state watches, debounced catalogue search and lazy category
rendering.

Player open, playback, fallback, seek, audio and recovery behavior are unchanged.
RC1 retains the Beta-5 `v2` database and its persisted settings.
