# Lunarr Player 1.0.3-rc.3

This preview addresses persistent audio/video stuttering when using large audio
offsets in Live TV. The ±60-second range and Windows fullscreen correction remain.
Version 1.0.2 remains the stable release.

## Audio sync buffering

The ordinary live profile disables automatic cache pauses. With separated audio
and video timelines, the leading track could exhaust its available packets while
the other track continued playing. Reading the accepted offset back from mpv did
not detect this playback problem.

While an audio offset is active, the player now reserves read-ahead for its
absolute duration plus five seconds and enables joint cache pauses on underruns.
The byte-cache limit grows when needed while preserving larger existing caches.
Resetting the offset restores the previous cache settings. All required engine
settings are verified; a rejected adjustment restores the preceding settings.

Large offsets on live sources still need an initial realignment or buffering
period because the stream arrives in real time. Allow this to finish before
judging the result. Persistent chopped audio or video afterward is a bug.

Open the audio menu and choose **Audio sync**. Negative values play sound earlier;
positive values play it later. Direct entry uses milliseconds: 15000 ms is 15
seconds. Press **Apply** after typing. Changing the channel/title resets the offset.

## Verification

41 session, dialog and player tests and 18 buffering tests passed. Native media_kit/mpv tests on Linux
verify the offset limits, local playback timing and a paced HTTP MPEG-TS live
stream at −15 and +15 seconds. The live test requires both tracks to advance
continuously with the expected offset and without ongoing cache underruns after
realignment. Static analysis passed. Confirm the result on the affected Windows
sender; a synthetic stream cannot reproduce every broadcaster or audio device.

## Portable Windows distribution

Extract `Lunarr-Player-1.0.3-rc.3-windows-x64-portable.zip` into its own folder and
run `lunarr_one.exe`. Keep the DLLs and `data/` folder beside it. Existing profiles
and settings use their existing per-user storage locations. A `.sha256` file
accompanies the archive.
