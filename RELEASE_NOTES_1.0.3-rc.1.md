# Lunarr Player 1.0.3-rc.1

This preview adds per-playback audio sync and corrects Windows fullscreen
geometry for Live TV, Xtream movies and series, and Jellyfin. Version 1.0.2
remains the stable release while these changes are tested on Windows.

## Fullscreen

- Playback uses the complete bounds of the current monitor, including the
  taskbar area, instead of applying work-area frame offsets.
- Fullscreen transitions share one window controller across all players.
- Leaving fullscreen restores the previous window placement and maximized state.
- Monitor coordinates stay physical when Windows reports a DPI or display change.

## Audio sync

Open the audio menu and choose **Audio sync**. Adjust sound timing from
-2000 to +2000 ms with the slider, 50 ms steps, or direct entry.
Positive values play sound later; negative values play it earlier.

The adjustment applies during playback without restarting it. A new channel or
title resets the offset to 0 ms. Pause, seeking, track changes, and reconnecting
the same source preserve it. **Reset** returns to 0 ms.

## Testing this preview

- Test fullscreen on both the 4K and 1080p monitor, including differing Windows
  scale settings, normal and maximized windows, repeated transitions, and moving
  the window between monitors before entering fullscreen.
- Confirm that the desktop and taskbar are covered while the player is focused.
- Check audio sync in Live TV, Xtream and Jellyfin; verify the reset after changing
  the channel, movie or episode and preservation after pause, seek and reconnect.

The application and changed tests passed static analysis. The targeted automated
suite passed 68 tests on Linux. Real Windows playback and mixed-monitor behavior
require testing with this preview.

## Portable Windows distribution

Extract the complete `Lunarr-Player-1.0.3-rc.1-windows-x64-portable.zip` into its own
folder and run `lunarr_one.exe`. Keep the DLLs and `data/` folder beside it.
Existing profiles and settings use their existing per-user storage locations.
The preview is not code-signed; SmartScreen may show a warning. A `.sha256` file
is included for checking the archive.
