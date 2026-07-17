import 'dart:convert';

import 'package:drift/drift.dart';

import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/logger/app_logger.dart';
import 'package:m3uxtream_player/core/models/series_resume_state.dart';

class AppStateKeys {
  const AppStateKeys._();

  static String epgReminderDismissed(int playlistId) =>
      'epg_reminder_dismissed_$playlistId';
  static String seriesResume(int playlistId, String seriesStreamId) =>
      'series_resume_${playlistId}_$seriesStreamId';
  static String hiddenGroups(int playlistId) => 'hidden_groups_$playlistId';
  static String pinnedGroups(int playlistId) => 'pinned_groups_$playlistId';

  static const playerBufferSeconds = 'player_buffer_seconds';
  static const vodPreBufferEnabled = 'vod_pre_buffer_enabled';
  static const vodPreBufferTargetSeconds = 'vod_pre_buffer_target_seconds';
  static const forceStereoEnabled = 'force_stereo_enabled';
  static const preferredAudioLanguage = 'preferred_audio_language';
  static const debugModeEnabled = 'debug_mode_enabled';
  static const streamingAutoFallbackEnabled = 'streaming_auto_fallback_enabled';
  static const streamingShowDiagnosisOnError =
      'streaming_show_diagnosis_on_error';
  static const inactivePlaylistIds = 'inactive_playlist_ids';
  static const appearanceAccentHue = 'appearanceAccentHue';
  static const appearanceSurfaceTone = 'appearanceSurfaceTone';
}

/// Shared key-value adapter for the feature-specific app-state stores.
class AppStateValueStore {
  AppStateValueStore(this._db);

  final AppDatabase _db;

  Future<String?> read(String key) async {
    final row = await (_db.select(
      _db.appStates,
    )..where((table) => table.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> write(String key, String value) async {
    await _db
        .into(_db.appStates)
        .insertOnConflictUpdate(
          AppStatesCompanion.insert(key: key, value: Value(value)),
        );
  }

  Future<void> delete(String key) async {
    await (_db.delete(
      _db.appStates,
    )..where((table) => table.key.equals(key))).go();
  }
}

class AppearanceStateStore {
  AppearanceStateStore(this._values);
  final AppStateValueStore _values;

  Future<double> getAccentHue({double defaultHue = 170}) async {
    try {
      final parsed = double.tryParse(
        await _values.read(AppStateKeys.appearanceAccentHue) ?? '',
      );
      return parsed?.clamp(0, 360).toDouble() ?? defaultHue;
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed reading appearance accent hue',
        error,
        stackTrace,
      );
      return defaultHue;
    }
  }

  Future<void> setAccentHue(double hue) async {
    await _write(
      AppStateKeys.appearanceAccentHue,
      hue.clamp(0, 360).toStringAsFixed(2),
      'appearance accent hue',
    );
  }

  Future<double> getSurfaceTone({double defaultTone = 0.5}) async {
    try {
      final parsed = double.tryParse(
        await _values.read(AppStateKeys.appearanceSurfaceTone) ?? '',
      );
      return parsed?.clamp(0, 1).toDouble() ?? defaultTone;
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed reading appearance surface tone',
        error,
        stackTrace,
      );
      return defaultTone;
    }
  }

  Future<void> setSurfaceTone(double tone) async {
    await _write(
      AppStateKeys.appearanceSurfaceTone,
      tone.clamp(0, 1).toStringAsFixed(3),
      'appearance surface tone',
    );
  }

  Future<void> _write(String key, String value, String label) async {
    try {
      await _values.write(key, value);
    } catch (error, stackTrace) {
      AppLogger.error('Failed writing $label', error, stackTrace);
      rethrow;
    }
  }
}

class PlaybackStateStore {
  PlaybackStateStore(this._values);
  final AppStateValueStore _values;

  Future<int> getBufferSeconds({int defaultSeconds = 15}) => _readInt(
    AppStateKeys.playerBufferSeconds,
    defaultValue: defaultSeconds,
    min: 0,
    max: 120,
    label: 'buffer seconds',
  );

  Future<void> setBufferSeconds(int seconds) => _write(
    AppStateKeys.playerBufferSeconds,
    '${seconds.clamp(0, 120)}',
    'buffer seconds',
  );

  Future<bool> getVodPreBufferEnabled({bool defaultEnabled = true}) =>
      _readBool(
        AppStateKeys.vodPreBufferEnabled,
        defaultValue: defaultEnabled,
        label: 'VOD pre-buffer flag',
      );

  Future<void> setVodPreBufferEnabled(bool enabled) => _writeBool(
    AppStateKeys.vodPreBufferEnabled,
    enabled,
    'VOD pre-buffer flag',
  );

  Future<int> getVodPreBufferTargetSeconds({int defaultSeconds = 90}) =>
      _readInt(
        AppStateKeys.vodPreBufferTargetSeconds,
        defaultValue: defaultSeconds,
        min: 15,
        max: 300,
        label: 'VOD pre-buffer seconds',
      );

  Future<void> setVodPreBufferTargetSeconds(int seconds) => _write(
    AppStateKeys.vodPreBufferTargetSeconds,
    '${seconds.clamp(15, 300)}',
    'VOD pre-buffer seconds',
  );

  Future<bool> getForceStereoEnabled({bool defaultEnabled = false}) =>
      _readBool(
        AppStateKeys.forceStereoEnabled,
        defaultValue: defaultEnabled,
        label: 'force stereo flag',
      );

  Future<void> setForceStereoEnabled(bool enabled) =>
      _writeBool(AppStateKeys.forceStereoEnabled, enabled, 'force stereo flag');

  Future<String?> getPreferredAudioLanguage() async {
    try {
      final normalized = (await _values.read(
        AppStateKeys.preferredAudioLanguage,
      ))?.trim();
      if (normalized == null ||
          normalized.isEmpty ||
          normalized.toLowerCase() == 'auto') {
        return null;
      }
      return normalized;
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed reading preferred audio language',
        error,
        stackTrace,
      );
      return null;
    }
  }

  Future<void> setPreferredAudioLanguage(String? language) {
    final trimmed = language?.trim();
    final value =
        trimmed == null || trimmed.isEmpty || trimmed.toLowerCase() == 'auto'
        ? ''
        : trimmed;
    return _write(
      AppStateKeys.preferredAudioLanguage,
      value,
      'preferred audio language',
    );
  }

  Future<int> _readInt(
    String key, {
    required int defaultValue,
    required int min,
    required int max,
    required String label,
  }) async {
    try {
      final parsed = int.tryParse(await _values.read(key) ?? '');
      return parsed?.clamp(min, max).toInt() ?? defaultValue;
    } catch (error, stackTrace) {
      AppLogger.error('Failed reading $label', error, stackTrace);
      return defaultValue;
    }
  }

  Future<bool> _readBool(
    String key, {
    required bool defaultValue,
    required String label,
  }) async {
    try {
      final raw = await _values.read(key);
      return raw == null ? defaultValue : raw == 'true';
    } catch (error, stackTrace) {
      AppLogger.error('Failed reading $label', error, stackTrace);
      return defaultValue;
    }
  }

  Future<void> _writeBool(String key, bool value, String label) =>
      _write(key, value ? 'true' : 'false', label);

  Future<void> _write(String key, String value, String label) async {
    try {
      await _values.write(key, value);
    } catch (error, stackTrace) {
      AppLogger.error('Failed writing $label', error, stackTrace);
      rethrow;
    }
  }
}

class DiagnosticsStateStore {
  DiagnosticsStateStore(this._values);
  final AppStateValueStore _values;

  Future<bool> getDebugModeEnabled({bool defaultEnabled = false}) => _read(
    AppStateKeys.debugModeEnabled,
    defaultValue: defaultEnabled,
    label: 'debug mode flag',
  );
  Future<void> setDebugModeEnabled(bool value) =>
      _write(AppStateKeys.debugModeEnabled, value, 'debug mode flag');
  Future<bool> getAutoFallbackEnabled({bool defaultEnabled = true}) => _read(
    AppStateKeys.streamingAutoFallbackEnabled,
    defaultValue: defaultEnabled,
    label: 'streaming auto fallback flag',
  );
  Future<void> setAutoFallbackEnabled(bool value) => _write(
    AppStateKeys.streamingAutoFallbackEnabled,
    value,
    'streaming auto fallback flag',
  );
  Future<bool> getShowDiagnosisOnError({bool defaultEnabled = true}) => _read(
    AppStateKeys.streamingShowDiagnosisOnError,
    defaultValue: defaultEnabled,
    label: 'streaming diagnosis toggle',
  );
  Future<void> setShowDiagnosisOnError(bool value) => _write(
    AppStateKeys.streamingShowDiagnosisOnError,
    value,
    'streaming diagnosis toggle',
  );

  Future<bool> _read(
    String key, {
    required bool defaultValue,
    required String label,
  }) async {
    try {
      final raw = await _values.read(key);
      return raw == null ? defaultValue : raw == 'true';
    } catch (error, stackTrace) {
      AppLogger.error('Failed reading $label', error, stackTrace);
      return defaultValue;
    }
  }

  Future<void> _write(String key, bool value, String label) async {
    try {
      await _values.write(key, value ? 'true' : 'false');
    } catch (error, stackTrace) {
      AppLogger.error('Failed writing $label', error, stackTrace);
      rethrow;
    }
  }
}

class PlaylistVisibilityStateStore {
  PlaylistVisibilityStateStore(this._values);
  final AppStateValueStore _values;

  Future<Set<int>> getInactivePlaylistIds() async {
    try {
      final raw = await _values.read(AppStateKeys.inactivePlaylistIds);
      if (raw == null || raw.isEmpty) return {};
      final decoded = jsonDecode(raw);
      if (decoded is! List) return {};
      return decoded
          .map((entry) => int.tryParse(entry.toString()))
          .whereType<int>()
          .toSet();
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed reading inactive playlist ids',
        error,
        stackTrace,
      );
      return {};
    }
  }

  Future<bool> isPlaylistActive(int playlistId) async {
    return !(await getInactivePlaylistIds()).contains(playlistId);
  }

  Future<void> setPlaylistActive(int playlistId, bool active) async {
    final inactive = await getInactivePlaylistIds();
    active ? inactive.remove(playlistId) : inactive.add(playlistId);
    await _write(
      AppStateKeys.inactivePlaylistIds,
      jsonEncode(inactive.toList()..sort()),
      'active state for playlist $playlistId',
    );
  }

  Future<Set<String>> getHiddenGroups(int playlistId) async {
    try {
      final raw = await _values.read(AppStateKeys.hiddenGroups(playlistId));
      if (raw == null || raw.isEmpty) return {};
      final decoded = jsonDecode(raw);
      return decoded is List
          ? decoded.map((entry) => entry.toString()).toSet()
          : {};
    } catch (error, stackTrace) {
      AppLogger.error('Failed reading hidden groups', error, stackTrace);
      return {};
    }
  }

  Future<void> setHiddenGroups(int playlistId, Set<String> hidden) => _write(
    AppStateKeys.hiddenGroups(playlistId),
    jsonEncode(hidden.toList()..sort()),
    'hidden groups',
  );

  Future<List<String>> getPinnedGroups(int playlistId) async {
    try {
      final raw = await _values.read(AppStateKeys.pinnedGroups(playlistId));
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      return decoded is List
          ? decoded.map((entry) => entry.toString()).toList(growable: false)
          : const [];
    } catch (error, stackTrace) {
      AppLogger.error('Failed reading pinned groups', error, stackTrace);
      return const [];
    }
  }

  Future<void> setPinnedGroups(int playlistId, List<String> pinned) => _write(
    AppStateKeys.pinnedGroups(playlistId),
    jsonEncode(pinned),
    'pinned groups',
  );

  Future<void> _write(String key, String value, String label) async {
    try {
      await _values.write(key, value);
    } catch (error, stackTrace) {
      AppLogger.error('Failed writing $label', error, stackTrace);
      rethrow;
    }
  }
}

class EpgReminderStateStore {
  EpgReminderStateStore(this._values);
  final AppStateValueStore _values;

  Future<bool> isDismissed(int playlistId) async {
    return await _values.read(AppStateKeys.epgReminderDismissed(playlistId)) ==
        'true';
  }

  Future<void> setDismissed(int playlistId, bool dismissed) async {
    await _values.write(
      AppStateKeys.epgReminderDismissed(playlistId),
      dismissed ? 'true' : 'false',
    );
    AppLogger.info(
      'AppStateRepository: EPG reminder dismiss for playlist $playlistId → $dismissed.',
    );
  }
}

class SeriesResumeStateStore {
  SeriesResumeStateStore(this._values);
  final AppStateValueStore _values;

  Future<SeriesResumeState?> get(int playlistId, String streamId) async {
    try {
      final raw = await _values.read(
        AppStateKeys.seriesResume(playlistId, streamId),
      );
      if (raw == null || raw.isEmpty) return null;
      return SeriesResumeState.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (error, stackTrace) {
      AppLogger.error('Failed reading series resume', error, stackTrace);
      return null;
    }
  }

  Future<void> set(
    int playlistId,
    String streamId,
    SeriesResumeState state,
  ) async {
    try {
      await _values.write(
        AppStateKeys.seriesResume(playlistId, streamId),
        jsonEncode(state.toJson()),
      );
    } catch (error, stackTrace) {
      AppLogger.error('Failed writing series resume', error, stackTrace);
      rethrow;
    }
  }

  Future<void> clear(int playlistId, String streamId) async {
    try {
      await _values.delete(AppStateKeys.seriesResume(playlistId, streamId));
    } catch (error, stackTrace) {
      AppLogger.error('Failed clearing series resume', error, stackTrace);
      rethrow;
    }
  }
}
