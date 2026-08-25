# Third-Party Notices

This document describes the principal native components bundled with the
Windows distribution of Lunarr Player 1.0.1. It is provided for attribution
and license compliance and is not legal advice.

The Flutter asset bundle also contains `data/flutter_assets/NOTICES.Z`, which
is Flutter's generated notice collection for Dart and Flutter dependencies.
The corresponding package versions are locked in `pubspec.lock` in the source
repository.

## Flutter and Dart

- Flutter 3.47.1 and Dart 3.13.1
- License: BSD 3-Clause and component-specific notices
- Source: <https://github.com/flutter/flutter/tree/3.47.1>
- License text: `third_party_licenses/Flutter-BSD-3-Clause.txt`

## media_kit

- `media_kit` 1.2.6
- `media_kit_video` 2.0.1
- `media_kit_libs_windows_video` 1.0.11
- Copyright: 2021 and onwards, Hitesh Kumar Saini
- License: MIT
- Source: <https://github.com/media-kit/media-kit>
- License text: `third_party_licenses/media_kit-MIT.txt`

## mpv / libmpv and FFmpeg

The file `libmpv-2.dll` is the unmodified binary selected by
`media_kit_libs_windows_video` 1.0.11:

- Archive: `mpv-dev-x86_64-20230924-git-652a1dd.7z`
- Archive release: <https://github.com/media-kit/libmpv-win32-video-build/releases/tag/2023-09-24>
- mpv version: `v0.36.0-403-g652a1dd907`
- mpv source: <https://github.com/mpv-player/mpv/tree/652a1dd90711839acdccc08004056d25514ef2d8>
- Build configuration reports `-Dgpl=false`
- FFmpeg version reported by libmpv: `n6.0`
- FFmpeg source: <https://github.com/FFmpeg/FFmpeg/tree/n6.0>
- License: GNU Lesser General Public License 2.1 or later for this
  GPL-disabled build, together with the compatible licenses of its individual
  dependencies
- License text: `third_party_licenses/LGPL-2.1.txt`

The libmpv binary is dynamically loaded. Recipients may replace it with a
compatible modified build. Nothing in Lunarr Player's installer or license is
intended to restrict debugging, reverse engineering for such modifications, or
the other rights granted by the LGPL.

## ANGLE graphics libraries

The Windows video output includes the unmodified ANGLE bundle selected by
`media_kit_libs_windows_video` 1.0.11:

- Bundle release: `flutter-windows-ANGLE-OpenGL-ES` v1.0.1
- Bundle source: <https://github.com/alexmercerind/flutter-windows-ANGLE-OpenGL-ES/tree/v1.0.1>
- ANGLE binaries report version `2.1.18844`, git hash `2693b03eba82`
- ANGLE source: <https://github.com/google/angle>
- License: BSD 3-Clause
- License text: `third_party_licenses/ANGLE-BSD-3-Clause.txt`

That bundle also contains SwiftShader/Vulkan components and zlib:

- SwiftShader (`vk_swiftshader.dll`, version 5.0.0) and the Vulkan loader are
  distributed under Apache License 2.0. Source:
  <https://github.com/google/swiftshader> and
  <https://github.com/KhronosGroup/Vulkan-Loader>.
- zlib is distributed under the zlib license. Source:
  <https://github.com/madler/zlib>.
- License texts: `third_party_licenses/Apache-2.0.txt` and
  `third_party_licenses/zlib.txt`.

## Microsoft redistributable components

The installer carries the Visual C++ runtime DLLs and Direct3D compiler DLL
permitted for redistribution with applications built using Microsoft Visual
Studio. They remain Microsoft components and are subject to the Microsoft
Visual Studio licensing terms.

## Inno Setup

The setup executable is compiled with Inno Setup 6.7.3. Inno Setup is
copyright Jordan Russell and Martijn Laan and is distributed under its own
license with commercial-distribution exceptions. Source and license:
<https://jrsoftware.org/isinfo.php>.
