# LUNARR One

LUNARR One is a Material 3 IPTV player for Windows desktop. It combines Live
TV, VOD, series, EPG, local favorites and practical diagnostics in one focused
desktop application.

> LUNARR One does not include channels, playlists or media content. You need
> your own IPTV playlist or Xtream-compatible provider access.

## Current Version

Release candidate: `0.9.0 RC1`

Git tag: `v0.9.0-rc.1`

## Supported Platforms

Currently supported:

- Windows desktop

Planned:

- iOS

Android, Linux and Web are not currently planned.

## Highlights

- Live TV playback with channel zapping
- Responsive Material 3 desktop interface
- High-contrast, reduced-motion and large-text support
- VOD and series catalogues with resume and Watch Later
- EPG grid, compact agenda and current-program display
- Playlist management with favorites, hidden and pinned categories
- Audio-track selection and optional stereo compatibility mode
- Configurable live startup buffer
- Stream fallback and redacted diagnostics tools
- Fast catalogue search and lazy rendering for large libraries

## Installation

Download the Windows portable ZIP from GitHub Releases:

1. Extract the complete ZIP to a directory of your choice.
2. Keep the included DLLs and `data` directory beside the executable.
3. Start `lunarr_one.exe`.

No installer or separate dependency download is required. Windows may show a
SmartScreen warning because the release executable is not code-signed.

### Updating from Beta 5

RC1 continues to use the existing local `v2` database. Playlists and settings
from Beta 5 remain compatible. The legacy Beta-4 database is still left
untouched and is not imported automatically.

## Building from Source

Requirements:

- Flutter SDK with Windows desktop support
- Visual Studio Windows desktop build tools
- Xcode on macOS for future iOS builds

```powershell
flutter pub get
flutter analyze lib test --no-pub
flutter test --concurrency=1 --no-pub
flutter build windows --release
```

The Windows build is generated under
`build/windows/x64/runner/Release`.

## Privacy

LUNARR One stores user data locally. Never commit or share personal playlists,
provider credentials, local databases, diagnostics exports or release ZIPs.
Release builds are produced from a neutral build path and scanned for private
paths and data before publication.

## License

Proprietary. See `LICENSE`.
