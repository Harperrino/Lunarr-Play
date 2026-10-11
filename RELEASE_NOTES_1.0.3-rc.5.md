# Lunarr Player 1.0.3-rc.5

This preview fixes premature audio-sync application and a readiness check that
could roll back a valid correction while the audio device was paused.

## Apply controls playback

Moving the slider, using the ± buttons, typing, switching fine adjustment,
resetting, and choosing original/correction now prepare a local draft only.
**Apply** is the only action that pauses, buffers and aligns playback. Pressing
Enter in the input no longer starts an adjustment. Closing without applying
discards the draft. **Applied** displays the currently committed offset beside
the draft, with a reminder to press Apply.

The ±60-second range, 10 ms fine adjustment and pre-buffer integration remain.
Original/correction comparison also requires Apply after selecting either value.

## Paused-device alignment

mpv's `audio-pts` reports the audio output clock. A paused device can keep its
previous clock until playback resumes, even after an exact seek has completed.
Waiting for that clock to match the new offset before resuming could time out
and restore zero. Alignment now waits for the seek to finish at the held video
position, verifies that the engine retains the requested offset, and then
resumes. Manually paused playback remains paused.

A temporarily unavailable native path property is not treated as a new source;
session/player ownership still guards sender changes and disposal. Interrupted
adjustments now display feedback, and progress/errors scroll into view rather
than being hidden below the controls. Cancellation retains its previous behavior.

## Verification

Regression tests cover paused output clocks retaining an old non-null timestamp
for both offset directions, manual pause preservation, and an engine rejecting
an offset after seeking. UI tests verify that all editing controls and Enter
perform no playback writes until Apply, drafts are discarded on Close, and
interrupted corrections display visible feedback. Native Linux media_kit/mpv
tests cover the offset limits and a paced live MPEG-TS source at −15/+15 seconds,
including buffering, cancellation and smooth advancement of both tracks.
Static analysis and the Windows portable build passed. Confirm playback on the
affected Windows sender/device with this preview.

Extract `Lunarr-Player-1.0.3-rc.5-windows-x64-portable.zip` into its own folder and
run `lunarr_one.exe`, keeping its DLLs and `data/` directory beside it. Existing
settings continue to use their per-user storage. A `.sha256` file accompanies
the archive. Version 1.0.2 remains the stable release.
