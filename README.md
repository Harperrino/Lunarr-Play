<p align="center">
  <img src="assets/branding/lunarr-player-wordmark.png"
       alt="Lunarr Player"
       width="720">
</p>

Lunarr Player is a modern IPTV and Jellyfin player for Windows. It brings live
television, movies, series, the programme guide and personal Jellyfin libraries
together in a focused desktop app with a clean Material 3 interface.

It is designed for quick navigation, large media libraries and comfortable
everyday use — whether you are switching between live channels, continuing a
series or looking through your provider's catalogue.

> Lunarr does not include channels, playlists or media content. You need
> your own M3U playlist, access to an Xtream-compatible provider or a Jellyfin
> server and account.

## Features

- Live TV playback with quick channel switching and fullscreen controls
- Support for M3U playlists and Xtream-compatible providers
- Multiple saved Jellyfin server and user profiles
- Jellyfin libraries, Continue Watching, Next Up and recently added media
- Jellyfin movie and series details with artwork, metadata and external IDs
- Direct Play-first Jellyfin playback with server-controlled fallback
- Episode navigation, season selection and immersive fullscreen playback
- A shared media library for movies, series and Watch Later
- Playback progress and resume support for VOD and series
- EPG grid, compact agenda and current-programme information
- Favorites and controls for hiding or pinning categories
- Fast search and efficient browsing for large catalogues
- Audio-track selection and an optional stereo compatibility mode
- Configurable startup buffering and stream fallback support
- Material 3 design with adjustable appearance settings
- High-contrast, reduced-motion and large-text options
- Built-in diagnostics with sensitive information redacted from exports

## Installation

The current Windows release is available as a portable ZIP through GitHub
Releases.

1. Download and extract the complete ZIP.
2. Keep the included DLL files and the `data` directory beside the executable.
3. Start `lunarr_one.exe`.

No installer or separate runtime download is required. Windows may display a
SmartScreen warning because the application is not currently code-signed.

## Current Status

The current release candidate is **Lunarr Player 0.10.0 RC1**
(`v0.10.0-rc.1`).

[See what is new in 0.10.0 RC1](CHANGELOG.md).

Windows desktop is the currently supported platform. Linux remains planned.
Jellyfin support is integrated directly and can be hidden completely when it
is not needed; the other main navigation tabs are configurable as well.

Existing 0.9.x installations keep using their local application database, so
playlists, settings, favorites and playback progress remain available after
updating. Jellyfin connection profiles are stored locally per Windows user.

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
