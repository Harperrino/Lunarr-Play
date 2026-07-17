import 'dart:async';

import 'package:media_kit/media_kit.dart';
import 'package:m3uxtream_player/core/logger/app_logger.dart';

/// Picks a valid audio track and cycles on decode failures (common with IPTV PMT quirks).
abstract final class LiveAudioTrackService {
  static const _preferredCodecs = [
    'aac',
    'mp4a',
    'ac3',
    'ac-3',
    'eac3',
    'ec-3',
    'mp3',
    'mp2',
    'opus',
  ];

  static bool isSelectable(AudioTrack track) {
    return !isSpecialTrack(track);
  }

  static bool isLikelyValid(AudioTrack track) {
    return isSelectable(track);
  }

  static bool isSpecialTrack(AudioTrack track) {
    return track.id == AudioTrack.auto().id || track.id == AudioTrack.no().id;
  }

  static String specialTrackLabel(AudioTrack track) {
    if (track.id == AudioTrack.auto().id) return 'auto';
    if (track.id == AudioTrack.no().id) return 'no';
    return 'none';
  }

  static List<AudioTrack> selectableTracks(Tracks tracks) {
    return tracks.audio.where(isSelectable).toList(growable: false);
  }

  static List<AudioTrack> validTracks(Tracks tracks) {
    // Keep all real audio tracks here; codec preference is applied later in pickBestFrom().
    return tracks.audio.where(isLikelyValid).toList();
  }

  static AudioTrack? pickBestFrom(
    List<AudioTrack> candidates, {
    bool preferStereo = false,
    String? preferredLanguage,
  }) {
    if (candidates.isEmpty) return null;
    if (candidates.length == 1) return candidates.first;

    final stereoCandidates = preferStereo
        ? candidates.where(isStereoTrack).toList(growable: false)
        : const <AudioTrack>[];
    final scoringCandidates = stereoCandidates.isNotEmpty
        ? stereoCandidates
        : candidates;

    final scored = scoringCandidates
        .map(
          (track) => (
            track: track,
            score: scoreTrack(track, preferredLanguage: preferredLanguage),
          ),
        )
        .toList(growable: false);

    scored.sort((a, b) => b.score.compareTo(a.score));

    final best = scored.first.track;
    if (preferStereo && isStereoTrack(best)) {
      AppLogger.info(
        'LiveAudioTrackService: Force stereo prefers native stereo track ${labelFor(best)}',
      );
    }
    return best;
  }

  static AudioTrack? pickBest(
    Tracks tracks, {
    bool preferStereo = false,
    String? preferredLanguage,
  }) {
    return pickBestFrom(
      validTracks(tracks),
      preferStereo: preferStereo,
      preferredLanguage: preferredLanguage,
    );
  }

  /// Ranks an audio track for automatic selection.
  ///
  /// Higher score = better candidate. Manual selection is handled by the caller
  /// and never passed here. Special tracks (auto/no) are filtered out before
  /// scoring. The algorithm is intentionally simple and stable:
  ///   - language match: +100 (if a preferred language is configured)
  ///   - known codec preference: +9 down to +1
  ///   - fallback unknown-but-real track: +0
  ///
  /// Note: a hard `preferStereo` preselection is handled in [pickBestFrom].
  static int scoreTrack(AudioTrack track, {String? preferredLanguage}) {
    if (isSpecialTrack(track)) return -1000;

    var score = 0;

    final canonicalPreferred = canonicalLanguageCode(preferredLanguage);
    if (canonicalPreferred != null && canonicalPreferred.isNotEmpty) {
      final trackCanonical = canonicalLanguageCode(track.language);
      if (trackCanonical == canonicalPreferred) {
        score += 100;
      }
    }

    final codec = (track.codec ?? '').toLowerCase();
    for (var i = 0; i < _preferredCodecs.length; i++) {
      if (codec.contains(_preferredCodecs[i])) {
        score += _preferredCodecs.length - i;
        break;
      }
    }

    return score;
  }

  static bool isStereoTrack(AudioTrack track) {
    if (isSpecialTrack(track)) return false;
    if (track.channelscount == 2) return true;
    final channels = track.channels?.trim().toLowerCase() ?? '';
    return channels.contains('stereo');
  }

  static AudioTrack? pickNextFrom(
    List<AudioTrack> candidates,
    int attemptIndex,
  ) {
    if (candidates.isEmpty) return null;
    return candidates[attemptIndex % candidates.length];
  }

  static AudioTrack? pickNext(Tracks tracks, int attemptIndex) {
    return pickNextFrom(validTracks(tracks), attemptIndex);
  }

  static Future<List<AudioTrack>> waitForSelectableTracks(
    Player player, {
    Duration timeout = const Duration(seconds: 3),
    Duration pollInterval = const Duration(milliseconds: 150),
    void Function(Tracks tracks, List<AudioTrack> selectableTracks)? onProgress,
  }) async {
    final start = DateTime.now();
    String? lastSignature;

    while (DateTime.now().difference(start) < timeout) {
      final tracks = player.state.tracks;
      final selectable = selectableTracks(tracks);
      final signature = _tracksSignature(tracks.audio, selectable);
      if (signature != lastSignature) {
        lastSignature = signature;
        onProgress?.call(tracks, selectable);
      }
      if (selectable.isNotEmpty) return selectable;
      await Future<void>.delayed(pollInterval);
    }

    final tracks = player.state.tracks;
    final selectable = selectableTracks(tracks);
    final signature = _tracksSignature(tracks.audio, selectable);
    if (signature != lastSignature) {
      onProgress?.call(tracks, selectable);
    }
    return selectable;
  }

  static String labelFor(AudioTrack track, {int? fallbackIndex}) {
    if (track.id == AudioTrack.auto().id) {
      return 'Auto';
    }
    if (track.id == AudioTrack.no().id) {
      return 'Keine';
    }

    final parts = <String>[];

    final language = _languageLabel(track.language);
    if (language != null && language.isNotEmpty) {
      parts.add(language);
    }

    final title = track.title?.trim();
    if (title != null && title.isNotEmpty) {
      parts.add(title);
    }

    final codec = _codecLabel(track.codec);
    if (codec != null && codec.isNotEmpty) {
      parts.add(codec);
    }

    final channels = _channelsLabel(track);
    if (channels != null && channels.isNotEmpty) {
      parts.add(channels);
    }

    if (parts.isEmpty) {
      return fallbackIndex != null ? 'Track $fallbackIndex' : 'Track';
    }

    return parts.join(' · ');
  }

  static Future<void> applyBestTrack(
    Player player, {
    List<AudioTrack>? tracks,
    bool preferStereo = false,
    String? preferredLanguage,
  }) async {
    final candidates = tracks ?? await waitForSelectableTracks(player);
    final best = pickBestFrom(
      candidates,
      preferStereo: preferStereo,
      preferredLanguage: preferredLanguage,
    );
    if (best == null) return;

    final currentId = player.state.track.audio.id;
    if (currentId == best.id) return;

    final score = scoreTrack(best, preferredLanguage: preferredLanguage);
    AppLogger.info(
      'LiveAudioTrackService: Selecting audio track ${labelFor(best)} '
      '(score=$score, preferStereo=$preferStereo, preferredLanguage=${preferredLanguage ?? 'auto'})',
    );
    await player.setAudioTrack(best);
  }

  static Future<bool> tryNextTrack(Player player, int attemptIndex) async {
    final next = pickNextFrom(
      selectableTracks(player.state.tracks),
      attemptIndex,
    );
    if (next == null) return false;

    AppLogger.info(
      'LiveAudioTrackService: Audio decode fallback → ${labelFor(next)}',
    );
    await player.setAudioTrack(next);
    return true;
  }

  static String? _codecLabel(String? codec) {
    final normalized = codec?.trim();
    if (normalized == null || normalized.isEmpty) return null;
    return switch (normalized.toLowerCase()) {
      'aac' || 'mp4a' || 'mp4a.40.2' => 'AAC',
      'ac3' || 'ac-3' => 'AC-3',
      'eac3' || 'ec-3' || 'e-ac-3' => 'E-AC-3',
      'mp2' => 'MP2',
      'mp3' => 'MP3',
      'opus' => 'Opus',
      _ => normalized.toUpperCase(),
    };
  }

  static String? _channelsLabel(AudioTrack track) {
    final count = track.channelscount;
    if (count != null) {
      return switch (count) {
        1 => 'Mono',
        2 => 'Stereo',
        6 => '5.1',
        8 => '7.1',
        _ => '$count ch',
      };
    }

    final label = track.channels?.trim();
    if (label == null || label.isEmpty) return null;
    return label;
  }

  /// Maps common language tags and names to a canonical ISO-639-1 code.
  ///
  /// Returns `null` for empty/unknown input so callers can treat "no preference"
  /// (null) differently from "unknown language metadata".
  static String? canonicalLanguageCode(String? language) {
    final normalized = language?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) return null;

    return switch (normalized) {
      'de' || 'deu' || 'ger' || 'german' || 'deutsch' => 'de',
      'en' || 'eng' || 'english' => 'en',
      'fr' || 'fra' || 'fre' || 'french' || 'français' || 'francais' => 'fr',
      'es' || 'spa' || 'spanish' || 'español' || 'espanol' => 'es',
      'it' || 'ita' || 'italian' || 'italiano' => 'it',
      'pt' || 'por' || 'portuguese' || 'português' || 'portugues' => 'pt',
      'tr' || 'tur' || 'turkish' || 'türkçe' || 'turkce' => 'tr',
      'ru' || 'rus' || 'russian' || 'русский' => 'ru',
      _ => normalized,
    };
  }

  /// Human-readable label for an audio language tag.
  static String? _languageLabel(String? language) {
    final normalized = language?.trim();
    if (normalized == null || normalized.isEmpty) return null;

    return switch (canonicalLanguageCode(normalized)) {
      'de' => 'Deutsch',
      'en' => 'English',
      'fr' => 'Français',
      'es' => 'Español',
      'it' => 'Italiano',
      'pt' => 'Português',
      'tr' => 'Türkçe',
      'ru' => 'Русский',
      _ => normalized,
    };
  }

  static String diagnosticLabelFor(AudioTrack track, {int? fallbackIndex}) {
    return 'id=${track.id} | ${labelFor(track, fallbackIndex: fallbackIndex)}';
  }

  static String diagnosticDetailsFor(AudioTrack track, {int? fallbackIndex}) {
    final parts = <String>[
      'id=${track.id}',
      if (fallbackIndex != null) 'index=$fallbackIndex',
      'title=${_diagnosticField(track.title)}',
      'language=${_diagnosticField(track.language)}',
      'codec=${_diagnosticField(_codecLabel(track.codec))}',
      'channels=${_diagnosticField(_diagnosticChannels(track))}',
      'special=${specialTrackLabel(track)}',
      'selectable=${isSelectable(track)}',
      'valid=${isLikelyValid(track)}',
    ];
    return parts.join(' | ');
  }

  static String trackFilterReason(AudioTrack track) {
    if (!isSelectable(track)) {
      return 'filtered: special track (${specialTrackLabel(track)})';
    }

    final codec = (track.codec ?? '').trim().toLowerCase();
    if (codec.isEmpty || codec == 'unknown' || codec == 'none') {
      return 'kept: codec metadata missing or unknown';
    }

    return 'kept: real audio track';
  }

  static String describeTracks(Iterable<AudioTrack> tracks) {
    final list = tracks.toList(growable: false);
    if (list.isEmpty) return '[]';

    return list
        .asMap()
        .entries
        .map((entry) {
          return diagnosticLabelFor(entry.value, fallbackIndex: entry.key + 1);
        })
        .join(', ');
  }

  static String _tracksSignature(
    List<AudioTrack> raw,
    List<AudioTrack> selectable,
  ) {
    final rawSignature = raw
        .map(
          (track) =>
              '${track.id}:${track.codec ?? ''}:${track.language ?? ''}:${track.title ?? ''}:${track.channelscount ?? ''}:${track.channels ?? ''}',
        )
        .join('|');
    final selectableSignature = selectable.map((track) => track.id).join('|');
    return '$rawSignature::$selectableSignature';
  }

  static String _diagnosticField(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return 'n/a';
    return text;
  }

  static String _diagnosticChannels(AudioTrack track) {
    final count = track.channelscount;
    if (count != null) {
      return _channelsLabel(track) ?? '$count ch';
    }

    final label = track.channels?.trim();
    if (label == null || label.isEmpty) return 'n/a';
    return label;
  }
}
