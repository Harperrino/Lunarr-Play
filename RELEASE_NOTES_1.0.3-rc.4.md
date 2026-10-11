# Lunarr Player 1.0.3-rc.4

This preview makes audio correction easier to compare and pauses both tracks
while rebuilding their playback positions. Version 1.0.2 remains stable.

## Audio sync controls

Open **Audio sync** in the audio menu. Separate picture and sound markers show
the selected offset, with a readable explanation in seconds. They visualize
your setting; they do not automatically measure lip sync.

The full range remains ±60 seconds. **Fine adjustment** zooms to ±500 ms around
the current value and uses 10 ms steps. Direct entry still accepts the full range.
**Compare with original** switches to zero; **Use correction** restores the
adjusted value. Switching the channel/title clears the correction and comparison.

## Pause, buffer and align

Applying a correction holds the current picture, pauses sound, collects the
required packets and seeks both tracks exactly to the held picture timestamp.
Playback then resumes with the new offset. A manually paused player stays paused.
The dialog displays buffering/alignment progress and offers cancellation.

For Live TV, the configured pre-buffer target is added to the separation between
the audio and video positions. For VOD/Jellyfin, the enabled pre-buffer target is
filled after alignment; disabling pre-buffer skips that extra wait. Required
cache limits grow without reducing an existing larger cache. Reset restores the
current playback profile, including profiles replaced by a seek or reconnect.

Live playback retains up to 256 MiB of past packets so later sound can be aligned
without advancing the held picture. This does not extend the startup wait.
History duration depends on bitrate. If the required past sound is unavailable,
or an offset crosses a file boundary, the adjustment fails and restores the
previous setting. Future packets can require waiting on a live source. Cancelling
restores the previous correction; a superseded operation cannot resume a newly
selected channel/title.

## Verification

Session, UI, Jellyfin and startup/pre-buffer regression tests cover direction,
fine steps, original comparison, progress, cancellation, source changes and
restoring the current cache profile. Native media_kit/mpv tests on Linux verify
both offset limits, manually paused alignment and a paced HTTP MPEG-TS live
source at −15/+15 seconds, including cancellation of a 60-second correction.
The live tests require continuous advancement of both tracks at the expected
offset after alignment. Static analysis passed. Windows sender/device behavior
still needs testing with this preview.

Extract `Lunarr-Player-1.0.3-rc.4-windows-x64-portable.zip` into its own folder and
run `lunarr_one.exe`. Keep the DLLs and `data/` directory beside it. Existing
profiles/settings continue to use their per-user storage. A `.sha256` file
accompanies the ZIP.
