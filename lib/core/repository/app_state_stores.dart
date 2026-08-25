import 'dart:convert';

import 'package:drift/drift.dart';

import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/logger/app_logger.dart';
import 'package:m3uxtream_player/core/models/series_resume_state.dart';
import 'package:m3uxtream_player/core/models/channel_sort_mode.dart';
import 'package:m3uxtream_player/core/models/epg_refresh_interval.dart';
import 'package:m3uxtream_player/core/models/playback_preferences.dart';
import 'package:m3uxtream_player/core/models/discovery_preferences.dart';
import 'package:m3uxtream_player/core/services/app_lifecycle_gate.dart';

class AppStateKeys {
  const AppStateKeys._();

  static String epgReminderDismissed(int playlistId) =>
      'epg_reminder_dismissed_$playlistId';
  static String seriesResume(int playlistId, String seriesStreamId) =>
      'series_resume_${playlistId}_$seriesStreamId';
  static String hiddenGroups(int playlistId) => 'hidden_groups_$playlistId';
  static String pinnedGroups(int playlistId) => 'pinned_groups_$playlistId';
  static String channelSortMode(int playlistId) =>
      'channel_sort_mode_$playlistId';
  static const allActiveChannelSortMode = 'all_active_channel_sort_mode';
  static String epgRefreshInterval(int playlistId) =>
      'epg_refresh_interval_$playlistId';

  static const playerBufferSeconds = 'player_buffer_seconds';
  static const vodPreBufferEnabled = 'vod_pre_buffer_enabled';
  static const vodPreBufferTargetSeconds = 'vod_pre_buffer_target_seconds';
  static const forceStereoEnabled = 'force_stereo_enabled';
  static const preferredAudioLanguage = 'preferred_audio_language';
  static const playbackSeekIntervalSeconds = 'playback_seek_interval_seconds';
  static const jellyfinTrickplayEnabled = 'jellyfin_trickplay_enabled';
  static const jellyfinMediaSegmentSkipMode =
      'jellyfin_media_segment_skip_mode';
  static const jellyfinNextEpisodeAutoplayEnabled =
      'jellyfin_next_episode_autoplay_enabled';
  static const jellyfinEndcardCountdownSeconds =
      'jellyfin_endcard_countdown_seconds';
  static const playerAmbientBackgroundEnabled =
      'player_ambient_background_enabled';
  static const playerAmbientPreset = 'player_ambient_preset';
  static const playerAmbientCustomHueA = 'player_ambient_custom_hue_a';
  static const playerAmbientCustomHueB = 'player_ambient_custom_hue_b';
  static const playerAmbientIntensity = 'player_ambient_intensity';
  static const playerAmbientMotion = 'player_ambient_motion';
  static const debugModeEnabled = 'debug_mode_enabled';
  static const streamingAutoFallbackEnabled = 'streaming_auto_fallback_enabled';
  static const streamingShowDiagnosisOnError =
      'streaming_show_diagnosis_on_error';
  static const inactivePlaylistIds = 'inactive_playlist_ids';
  static const appearanceAccentHue = 'appearanceAccentHue';
  static const appearanceSurfaceTone = 'appearanceSurfaceTone';
  static const categoryPaneWidth = 'category_pane_width';
  static const hiddenShellTabs = 'hidden_shell_tabs';
  static const discoverySource = 'discovery_source';
  static const discoverySeerrEndpoint = 'discovery_seerr_endpoint';
  static const startupDestination = 'startup_destination';
  static const startupPreferenceInitialized = 'startup_preference_initialized';
}

/// Shared key-value adapter for the feature-specific app-state stores.
class AppStateValueStore {
  AppStateValueStore(this._db, {this.lifecycleGate});

  final AppDatabase _db;
  final AppLifecycleGate? lifecycleGate;

  Future<String?> read(String key) async {
    final row = await (_db.select(
      _db.appStates,
    )..where((table) => table.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> write(String key, String value) async {
    lifecycleGate?.ensureWritable();
    final operation = _db
        .into(_db.appStates)
        .insertOnConflictUpdate(
          AppStatesCompanion.insert(key: key, value: Value(value)),
        );
    await (lifecycleGate?.track(operation) ?? operation);
  }

  Future<void> delete(String key) async {
    lifecycleGate?.ensureWritable();
    final operation = (_db.delete(
      _db.appStates,
    )..where((table) => table.key.equals(key))).go();
    await (lifecycleGate?.track(operation) ?? operation);
  }

  Future<bool> get hasAnyValue async {
    final row = await (_db.select(_db.appStates)..limit(1)).getSingleOrNull();
    return row != null;
  }

  Future<bool> get hasEstablishedData async {
    if (await hasAnyValue) return true;
    final playlist = await (_db.select(
      _db.playlists,
    )..limit(1)).getSingleOrNull();
    if (playlist != null) return true;
    final channel = await (_db.select(
      _db.channels,
    )..limit(1)).getSingleOrNull();
    return channel != null;
  }
}

class DiscoveryStateStore {
  DiscoveryStateStore(this._values);

  final AppStateValueStore _values;

  Future<DiscoveryPreferences> getPreferences() async {
    final source = DiscoverySource.fromStorage(
      await _values.read(AppStateKeys.discoverySource),
    );
    final endpoint =
        (await _values.read(AppStateKeys.discoverySeerrEndpoint) ?? '').trim();
    final storedStartup = await _values.read(AppStateKeys.startupDestination);
    final initialized =
        await _values.read(AppStateKeys.startupPreferenceInitialized) == 'true';

    AppStartupDestination startup;
    if (initialized || storedStartup != null) {
      startup = AppStartupDestination.fromStorage(storedStartup);
    } else {
      // Before this feature existed, established installations already had at
      // least one AppState value. Preserve their historical Live start.
      startup = await _values.hasEstablishedData
          ? AppStartupDestination.live
          : AppStartupDestination.home;
      await _values.write(AppStateKeys.startupDestination, startup.name);
      await _values.write(AppStateKeys.startupPreferenceInitialized, 'true');
    }

    return DiscoveryPreferences(
      source: source,
      seerrEndpoint: endpoint,
      startupDestination: startup,
    );
  }

  Future<void> setSource(DiscoverySource source) =>
      _values.write(AppStateKeys.discoverySource, source.name);

  Future<void> setSeerrEndpoint(String endpoint) =>
      _values.write(AppStateKeys.discoverySeerrEndpoint, endpoint.trim());

  Future<void> setStartupDestination(AppStartupDestination destination) async {
    await _values.write(AppStateKeys.startupDestination, destination.name);
    await _values.write(AppStateKeys.startupPreferenceInitialized, 'true');
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

  Future<PlaybackPreferences> getPreferences() async {
    final rawAmbientPreset = await _values.read(
      AppStateKeys.playerAmbientPreset,
    );
    final ambientPreset = PlayerAmbientPreset.fromStorage(rawAmbientPreset);
    if (rawAmbientPreset != null && rawAmbientPreset != ambientPreset.name) {
      try {
        await _write(
          AppStateKeys.playerAmbientPreset,
          ambientPreset.name,
          'normalized player ambient preset',
        );
      } catch (_) {
        // A failed canonical write must not prevent preferences from loading.
      }
    }
    return PlaybackPreferences(
      seekIntervalSeconds: normalizePlaybackSeekInterval(
        await _readInt(
          AppStateKeys.playbackSeekIntervalSeconds,
          defaultValue: 15,
          min: 5,
          max: 60,
          label: 'playback seek interval',
        ),
      ),
      trickplayEnabled: await _readBool(
        AppStateKeys.jellyfinTrickplayEnabled,
        defaultValue: true,
        label: 'Jellyfin trickplay flag',
      ),
      mediaSegmentSkipMode: MediaSegmentSkipMode.fromStorage(
        await _values.read(AppStateKeys.jellyfinMediaSegmentSkipMode),
      ),
      nextEpisodeAutoplayEnabled: await _readBool(
        AppStateKeys.jellyfinNextEpisodeAutoplayEnabled,
        defaultValue: true,
        label: 'Jellyfin next episode autoplay flag',
      ),
      endcardCountdownSeconds: normalizeEndcardCountdown(
        await _readInt(
          AppStateKeys.jellyfinEndcardCountdownSeconds,
          defaultValue: 10,
          min: 5,
          max: 30,
          label: 'Jellyfin endcard countdown',
        ),
      ),
      ambientBackgroundEnabled: await _readBool(
        AppStateKeys.playerAmbientBackgroundEnabled,
        defaultValue: true,
        label: 'player ambient background flag',
      ),
      ambientPreset: ambientPreset,
      ambientCustomHueA: normalizeAmbientHue(
        await _readDouble(
          AppStateKeys.playerAmbientCustomHueA,
          defaultValue: 215,
          min: 0,
          max: 360,
          label: 'player ambient first hue',
        ),
      ),
      ambientCustomHueB: normalizeAmbientHue(
        await _readDouble(
          AppStateKeys.playerAmbientCustomHueB,
          defaultValue: 285,
          min: 0,
          max: 360,
          label: 'player ambient second hue',
        ),
      ),
      ambientIntensity: normalizeAmbientIntensity(
        await _readDouble(
          AppStateKeys.playerAmbientIntensity,
          defaultValue: 0.55,
          min: 0,
          max: 1,
          label: 'player ambient intensity',
        ),
      ),
      ambientMotion: PlayerAmbientMotion.fromStorage(
        await _values.read(AppStateKeys.playerAmbientMotion),
      ),
    );
  }

  Future<void> setSeekIntervalSeconds(int seconds) => _write(
    AppStateKeys.playbackSeekIntervalSeconds,
    '${normalizePlaybackSeekInterval(seconds)}',
    'playback seek interval',
  );

  Future<void> setTrickplayEnabled(bool enabled) => _writeBool(
    AppStateKeys.jellyfinTrickplayEnabled,
    enabled,
    'Jellyfin trickplay flag',
  );

  Future<void> setMediaSegmentSkipMode(MediaSegmentSkipMode mode) => _write(
    AppStateKeys.jellyfinMediaSegmentSkipMode,
    mode.name,
    'Jellyfin media segment skip mode',
  );

  Future<void> setNextEpisodeAutoplayEnabled(bool enabled) => _writeBool(
    AppStateKeys.jellyfinNextEpisodeAutoplayEnabled,
    enabled,
    'Jellyfin next episode autoplay flag',
  );

  Future<void> setEndcardCountdownSeconds(int seconds) => _write(
    AppStateKeys.jellyfinEndcardCountdownSeconds,
    '${normalizeEndcardCountdown(seconds)}',
    'Jellyfin endcard countdown',
  );

  Future<void> setAmbientBackgroundEnabled(bool enabled) => _writeBool(
    AppStateKeys.playerAmbientBackgroundEnabled,
    enabled,
    'player ambient background flag',
  );

  Future<void> setAmbientPreset(PlayerAmbientPreset preset) => _write(
    AppStateKeys.playerAmbientPreset,
    preset.name,
    'player ambient preset',
  );

  Future<void> setAmbientCustomHueA(double value) => _write(
    AppStateKeys.playerAmbientCustomHueA,
    '${normalizeAmbientHue(value)}',
    'player ambient first hue',
  );

  Future<void> setAmbientCustomHueB(double value) => _write(
    AppStateKeys.playerAmbientCustomHueB,
    '${normalizeAmbientHue(value)}',
    'player ambient second hue',
  );

  Future<void> setAmbientIntensity(double value) => _write(
    AppStateKeys.playerAmbientIntensity,
    '${normalizeAmbientIntensity(value)}',
    'player ambient intensity',
  );

  Future<void> setAmbientMotion(PlayerAmbientMotion motion) => _write(
    AppStateKeys.playerAmbientMotion,
    motion.name,
    'player ambient motion',
  );

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
      return switch (raw) {
        'true' => true,
        'false' => false,
        _ => defaultValue,
      };
    } catch (error, stackTrace) {
      AppLogger.error('Failed reading $label', error, stackTrace);
      return defaultValue;
    }
  }

  Future<double> _readDouble(
    String key, {
    required double defaultValue,
    required double min,
    required double max,
    required String label,
  }) async {
    try {
      final parsed = double.tryParse(await _values.read(key) ?? '');
      return parsed?.clamp(min, max).toDouble() ?? defaultValue;
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

class CatalogueStateStore {
  CatalogueStateStore(this._values);
  final AppStateValueStore _values;

  Future<ChannelSortMode> getChannelSortMode(int playlistId) async {
    try {
      return channelSortModeFromStorage(
        await _values.read(AppStateKeys.channelSortMode(playlistId)),
      );
    } catch (error, stackTrace) {
      AppLogger.error('Failed reading channel sort mode', error, stackTrace);
      return ChannelSortMode.providerDefault;
    }
  }

  Future<void> setChannelSortMode(int playlistId, ChannelSortMode mode) async {
    try {
      await _values.write(
        AppStateKeys.channelSortMode(playlistId),
        mode.storageValue,
      );
    } catch (error, stackTrace) {
      AppLogger.error('Failed writing channel sort mode', error, stackTrace);
      rethrow;
    }
  }

  Future<ChannelSortMode> getAllActiveChannelSortMode() async {
    try {
      return channelSortModeFromStorage(
        await _values.read(AppStateKeys.allActiveChannelSortMode),
      );
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed reading All-active channel sort mode',
        error,
        stackTrace,
      );
      return ChannelSortMode.providerDefault;
    }
  }

  Future<void> setAllActiveChannelSortMode(ChannelSortMode mode) async {
    try {
      await _values.write(
        AppStateKeys.allActiveChannelSortMode,
        mode.storageValue,
      );
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed writing All-active channel sort mode',
        error,
        stackTrace,
      );
      rethrow;
    }
  }
}

class LayoutStateStore {
  LayoutStateStore(this._values);

  final AppStateValueStore _values;

  Future<double> getCategoryPaneWidth({double defaultWidth = 232}) async {
    try {
      final parsed = double.tryParse(
        await _values.read(AppStateKeys.categoryPaneWidth) ?? '',
      );
      return (parsed ?? defaultWidth).clamp(200, 420).toDouble();
    } catch (error, stackTrace) {
      AppLogger.error('Failed reading category pane width', error, stackTrace);
      return defaultWidth;
    }
  }

  Future<void> setCategoryPaneWidth(double width) async {
    final bounded = width.clamp(200, 420).toDouble();
    try {
      await _values.write(
        AppStateKeys.categoryPaneWidth,
        bounded.toStringAsFixed(1),
      );
    } catch (error, stackTrace) {
      AppLogger.error('Failed writing category pane width', error, stackTrace);
      rethrow;
    }
  }

  Future<Set<String>> getHiddenShellTabs() async {
    try {
      final raw = await _values.read(AppStateKeys.hiddenShellTabs);
      if (raw == null || raw.isEmpty) return {};
      final decoded = jsonDecode(raw);
      return decoded is List
          ? decoded.map((item) => item.toString()).toSet()
          : {};
    } catch (error, stackTrace) {
      AppLogger.error('Failed reading hidden shell tabs', error, stackTrace);
      return {};
    }
  }

  Future<void> setHiddenShellTabs(Set<String> tabKinds) async {
    try {
      await _values.write(
        AppStateKeys.hiddenShellTabs,
        jsonEncode(tabKinds.toList()..sort()),
      );
    } catch (error, stackTrace) {
      AppLogger.error('Failed writing hidden shell tabs', error, stackTrace);
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

class EpgRefreshIntervalStateStore {
  EpgRefreshIntervalStateStore(this._values);
  final AppStateValueStore _values;

  Future<EpgRefreshInterval> getInterval(int playlistId) async {
    try {
      return EpgRefreshInterval.fromStorage(
        await _values.read(AppStateKeys.epgRefreshInterval(playlistId)),
      );
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed reading EPG refresh interval for playlist $playlistId',
        error,
        stackTrace,
      );
      return EpgRefreshInterval.manual;
    }
  }

  Future<void> setInterval(int playlistId, EpgRefreshInterval interval) async {
    try {
      await _values.write(
        AppStateKeys.epgRefreshInterval(playlistId),
        interval.storageValue,
      );
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed writing EPG refresh interval for playlist $playlistId',
        error,
        stackTrace,
      );
      rethrow;
    }
  }

  Future<void> clearInterval(int playlistId) async {
    try {
      await _values.delete(AppStateKeys.epgRefreshInterval(playlistId));
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed clearing EPG refresh interval for playlist $playlistId',
        error,
        stackTrace,
      );
      rethrow;
    }
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
