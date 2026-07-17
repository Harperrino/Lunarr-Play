# Lunarr One

LUNARR One is a modern M3U/Xtream player for Windows. It brings live television,
movies, series and the programme guide together in a focused desktop app with a
clean Material 3 interface.

It is designed for quick navigation, large media libraries and comfortable
everyday use — whether you are switching between live channels, continuing a
series or looking through your provider's catalogue.

> Lunarr One does not include channels, playlists or media content. You need
> your own M3U playlist or access to an Xtream-compatible provider.

## Features

- Live TV playback with quick channel switching and fullscreen controls
- Support for M3U playlists and Xtream-compatible providers
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

The current release candidate is **LUNARR One 0.9.0 RC1**
(`v0.9.0-rc.1`).

Windows desktop is the currently supported platform. An iOS version is planned.
Android, Linux and Web versions are not currently planned.

Existing Beta 5 installations can continue using their local `v2` database, so
playlists and settings remain available after updating to RC1.

## Data and Privacy

LUNARR One stores its playlists, settings and playback data locally. Playlist
files, provider credentials, local databases and diagnostics exports may contain
private information and should not be published or shared without checking their
contents first.

## Building from Source

LUNARR One is built with Flutter. A Windows build requires:

- Flutter with Windows desktop support
- Visual Studio with the Desktop development with C++ workload

```powershell
flutter pub get
flutter analyze lib test --no-pub
flutter test --concurrency=1 --no-pub
flutter build windows --release
```

## License

LUNARR One is available under the [MIT License](LICENSE).
