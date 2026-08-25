import 'package:media_kit/media_kit.dart';
import 'package:m3uxtream_player/features/jellyfin/models/jellyfin_playback_info.dart';

/// Matches Jellyfin's source-local subtitle index to media_kit's MPV track.
///
/// MPV track ids are not Jellyfin stream indices. Prefer unique metadata
/// matches and use the source-local subtitle order only as a deterministic
/// fallback.
SubtitleTrack? jellyfinNativeSubtitleTrackFor({
  required int selectedStreamIndex,
  required List<JellyfinMediaStream> jellyfinTracks,
  required List<SubtitleTrack> nativeTracks,
}) {
  final selected = jellyfinTracks
      .where((track) => track.index == selectedStreamIndex)
      .firstOrNull;
  if (selected == null) return null;

  final selectable = nativeTracks
      .where((track) => track.id != 'auto' && track.id != 'no')
      .toList(growable: false);
  if (selectable.isEmpty) return null;

  final language = _normalized(selected.language);
  final codec = _normalizedCodec(selected.codec);
  if (language.isNotEmpty && codec.isNotEmpty) {
    final match = _uniqueMatch(
      selectable,
      (track) =>
          _normalized(track.language) == language &&
          _normalizedCodec(track.codec) == codec,
    );
    if (match != null) return match;
  }

  final title = _normalized(
    selected.title.isNotEmpty ? selected.title : selected.displayTitle,
  );
  if (language.isNotEmpty && title.isNotEmpty) {
    final match = _uniqueMatch(
      selectable,
      (track) =>
          _normalized(track.language) == language &&
          _normalized(track.title) == title,
    );
    if (match != null) return match;
  }

  final sourceSubtitles = jellyfinTracks
      .where((track) => track.type == JellyfinMediaStreamType.subtitle)
      .toList(growable: false);
  final ordinal = sourceSubtitles.indexWhere(
    (track) => track.index == selectedStreamIndex,
  );
  if (ordinal >= 0 && ordinal < selectable.length) return selectable[ordinal];
  return selectable.length == 1 ? selectable.single : null;
}

SubtitleTrack? _uniqueMatch(
  List<SubtitleTrack> tracks,
  bool Function(SubtitleTrack) matches,
) {
  SubtitleTrack? result;
  for (final track in tracks) {
    if (!matches(track)) continue;
    if (result != null) return null;
    result = track;
  }
  return result;
}

String _normalized(String? value) => value?.trim().toLowerCase() ?? '';

String _normalizedCodec(String? value) {
  return switch (_normalized(value)) {
    'srt' || 'subrip' => 'subrip',
    'pgssub' || 'hdmv_pgs_subtitle' => 'pgssub',
    'vobsub' || 'dvd_subtitle' => 'vobsub',
    final value => value,
  };
}
