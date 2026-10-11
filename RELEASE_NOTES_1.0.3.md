# Lunarr Player 1.0.3

## Playback fullscreen

Windows playback fullscreen fills the selected monitor and hides the taskbar,
including mixed 4K/1080p monitor setups. Leaving fullscreen restores the window.

## Audio sync

Audio sync supports ±60 seconds per playback. Open **Audio sync** from the audio
menu. Negative values play sound earlier; positive values play it later.
Separate picture/sound markers and readable seconds visualize the chosen offset.
The markers display your setting, not an automatic lip-sync measurement.

**Fine adjustment** uses 10 ms steps within ±500 ms of the current value. The
full range remains available through direct entry and the ordinary slider.
**Compare with original** prepares zero; **Use correction** restores the draft.

All controls prepare a draft. Only **Apply** pauses playback, buffers the required
data and aligns both tracks at the held picture position. **Applied** displays
the active correction. Closing without applying discards edits. Switching the
channel/title resets the correction. A manually paused player remains paused.

The configured pre-buffer target is respected in addition to the track offset.
Large live corrections may need to wait for incoming data. Past packets are
retained in a bounded cache; if the required sound is unavailable, the player
reports this and restores the previous setting. Progress, cancellation and
failure messages are visible. Paused audio-device clocks no longer make valid
corrections time out and roll back.

## Version and updates

Settings display the installed player's version. At each launch the player
checks the public GitHub repository once for a newer full release, excluding
pre-releases and drafts. A notice beside the Lunarr logo opens the release page.
Narrow windows use an icon with a tooltip. Network failures do not block startup
and are not retried automatically. Updates are downloaded and installed manually.

## Portable Windows package

Extract `Lunarr-Player-1.0.3-windows-x64-portable.zip` into its own folder and run
`lunarr_one.exe`. Keep the DLLs and `data/` directory beside it. Existing profiles
and settings retain their per-user storage. The ZIP includes the required native
libraries, runtime and license notices; a `.sha256` file accompanies it.

## Verification

The playback corrections were confirmed by the user on Windows in the RC series.
Native Linux media_kit/mpv tests cover live ±15-second corrections, smooth track
advancement, cancellation and manually paused alignment. Version/update tests
cover full-release comparisons, one startup request, failure handling and header
layout. Static analysis and the Windows packaging workflow validate this build.
