# Lunarr Player 1.0.3-rc.2

This preview expands audio sync in Live TV, Xtream and Jellyfin. It also includes
the Windows fullscreen correction from RC1. Version 1.0.2 remains the stable release.

## Audio sync

Open the audio menu and choose **Audio sync**. The range is now **−60,000 to
+60,000 ms (±60 seconds)**. The slider, 50 ms buttons and direct entry are available.

- If sound is behind the picture, use a negative value to play it earlier.
  For example, −5000 ms compensates for sound that is five seconds late.
- If sound is ahead of the picture, use a positive value to play it later.
  For example, +5000 ms compensates for sound that is five seconds early.

Use **Apply** after typing a value. The slider applies when released; the buttons
apply immediately. The player now reads the offset back from the playback engine
before confirming an adjustment and shows an error if the engine did not accept it.

A new channel or title resets the offset to zero. Pause, seeking, track changes
and reconnecting the same source preserve it. **Reset** returns to zero.
Large timing changes can briefly interrupt playback while the tracks realign.
Live streams need the required audio/video data to be available; the adjustment
does not repair missing packets or changing timestamp errors.

## Verification

39 automated session, dialog and player tests passed. Two native media_kit/mpv
tests passed on Linux, including both ±60-second limits and timing changes during
playback of an artificial audio/video file. Static analysis passed. Confirm the
result with an affected sender on Windows; synthetic playback does not establish
how every live source behaves.

## Portable Windows distribution

Extract the complete `Lunarr-Player-1.0.3-rc.2-windows-x64-portable.zip` into its own
folder and run `lunarr_one.exe`. Keep the DLLs and `data/` folder beside it.
Existing profiles and settings use their existing per-user storage locations.
A `.sha256` file accompanies the archive.
