<p align="center">
  <img src="assets/branding/lunarr-player-wordmark.png"
       alt="Lunarr Player"
       width="720">
</p>

Lunarr Player is a feature-complete IPTV, Jellyfin and media-discovery player
for Windows. It brings live television, movies, series, the programme guide,
personal Jellyfin libraries, TMDB and Seerr together in one focused desktop
app with a modern Material 3 Expressive interface.

It is designed for quick navigation, large media libraries and comfortable
everyday use — whether you are switching between live channels, continuing a
series or looking through your provider's catalogue.

> Lunarr does not include channels, playlists or media content. You need
> your own M3U playlist, access to an Xtream-compatible provider or a Jellyfin
> server and account.

## Highlights

### IPTV, VOD and Jellyfin

- M3U playlists and Xtream-compatible providers, including Live TV, movies
  and series
- Bundled MPV/libmpv playback: no separate media player or runtime installation
  is required
- Multiple playlists with provider-order, alphabetical and numeric catalogue
  sorting; sources can be enabled or disabled dynamically and switched from
  the top bar
- Favorites, Watch Later, hideable and pinnable playlist categories, playback
  progress and resume support
- Global Live TV search, a responsive EPG grid, compact agenda and current
  programme information
- Multiple local Jellyfin server and user profiles with fast account switching
  from the top bar
- Jellyfin libraries, Continue Watching, Next Up, recently added media,
  responsive series details and an in-player season/episode browser
- Direct Play-first Jellyfin playback with server-controlled Direct Stream or
  transcoding fallback

### Playback quality of life

- Configurable forward/back skip buttons for on-demand media
- Configurable Live TV startup buffering and VOD pre-buffering to reduce
  interruptions
- Audio-track selection and an optional stereo compatibility mode
- Jellyfin trickplay thumbnails while scrubbing when supplied by the server
- Jellyfin intro/recap skip buttons or automatic skipping, plus outro-aware
  endcards and configurable next-episode autoplay when segment data is
  available
- Fullscreen playback, keyboard controls, episode navigation and resilient
  stream fallback handling

### Discovery and services

- TMDB-powered trending, popular, upcoming, on-air and top-rated discovery,
  including search, details and external trailer links
- Optional Seerr integration for discovery, availability/request status and
  confirmed movie or season requests
- TMDB and Seerr can be configured together and switched beside the Home search

### Interface and customization

- Modern Material 3 Expressive UI with responsive desktop layouts
- Adjustable accent and surface colors plus an optional configurable Lunarr
  ambient background
- Hideable primary tabs for features you do not use
- High-contrast, reduced-motion, keyboard/focus and large-text support

### Local data and privacy

- Playlists, settings, favorites and playback state stay on the local device
- Sensitive values are masked in settings, diagnostics and logs
- Jellyfin credentials and discovery API keys are protected through the
  Windows DPAPI-backed secret stores and are never logged

## Installation

The current Windows x64 release is available as a portable ZIP through GitHub
Releases.

1. Download `Lunarr-Player-1.0.0-windows-x64.zip` and extract it completely.
2. Keep the included DLL files and the `data` directory beside the executable.
3. Start `lunarr_one.exe`.

The archive already contains MPV/libmpv and every required application runtime:
extract and start. No installer or separate resource download is required.
Windows may display a SmartScreen warning because the application is not
currently code-signed.

## Current Status

The current stable release is **Lunarr Player 1.0.0** (`v1.0.0`).

[See what is new in 1.0.0](CHANGELOG.md).

Windows desktop is the currently supported platform. Android smartphone and
foldable support is the next planned platform effort; Android TV is a separate
future consideration. Jellyfin and other primary navigation areas can be
hidden completely when they are not needed.

Lunarr Player 1.0 is considered feature complete. Development now focuses on
bug fixes and project maintenance. New features will be added selectively when
they materially improve the simple, quality-of-life-focused player experience.

Existing 0.9.x and 0.10.x installations keep using their local application
database, so playlists, settings, favorites and playback progress remain
available after updating. Jellyfin connection profiles are stored locally per
Windows user.

## Data and Privacy

Lunarr stores its playlists, settings and playback data locally. Playlist
files, provider credentials, local databases and diagnostics exports may contain
private information and should not be published or shared without checking their
contents first.

## Building from Source

Lunarr is built with Flutter. A Windows build requires:

- Flutter 3.47 or newer with Windows desktop support
- Visual Studio with the Desktop development with C++ workload

```powershell
flutter pub get
flutter analyze lib test --no-pub
flutter test --concurrency=1 --no-pub
flutter build windows --release
```

## Contributors

- **Harperrino** — creator and maintainer
- **Codex by OpenAI** ([@codex](https://github.com/codex)) — AI-engineering, refactoring,
  UI quality assurance, testing, release
  verification and documentation

## License

Lunarr Player is available under the [MIT License](LICENSE).
