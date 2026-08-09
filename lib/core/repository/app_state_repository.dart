import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/models/series_resume_state.dart';
import 'package:m3uxtream_player/core/models/channel_sort_mode.dart';
import 'package:m3uxtream_player/core/models/epg_refresh_interval.dart';
import 'package:m3uxtream_player/core/repository/app_state_stores.dart';
import 'package:m3uxtream_player/core/services/app_lifecycle_gate.dart';

export 'package:m3uxtream_player/core/models/series_resume_state.dart';

/// Backwards-compatible facade over feature-specific app-state stores.
///
/// Existing callers and persisted keys remain unchanged. New persistence
/// behavior should be added to the appropriate store rather than growing this
/// facade with database logic.
class AppStateRepository {
  AppStateRepository(AppDatabase database, {AppLifecycleGate? lifecycleGate})
    : _values = AppStateValueStore(database, lifecycleGate: lifecycleGate) {
    _appearance = AppearanceStateStore(_values);
    _playback = PlaybackStateStore(_values);
    _diagnostics = DiagnosticsStateStore(_values);
    _playlistVisibility = PlaylistVisibilityStateStore(_values);
    _epgReminder = EpgReminderStateStore(_values);
    _epgRefreshInterval = EpgRefreshIntervalStateStore(_values);
    _seriesResume = SeriesResumeStateStore(_values);
    _catalogue = CatalogueStateStore(_values);
    _layout = LayoutStateStore(_values);
  }

  final AppStateValueStore _values;
  late final AppearanceStateStore _appearance;
  late final PlaybackStateStore _playback;
  late final DiagnosticsStateStore _diagnostics;
  late final PlaylistVisibilityStateStore _playlistVisibility;
  late final EpgReminderStateStore _epgReminder;
  late final EpgRefreshIntervalStateStore _epgRefreshInterval;
  late final SeriesResumeStateStore _seriesResume;
  late final CatalogueStateStore _catalogue;
  late final LayoutStateStore _layout;

  static String epgReminderDismissedKey(int playlistId) =>
      AppStateKeys.epgReminderDismissed(playlistId);
  static String seriesResumeKey(int playlistId, String seriesStreamId) =>
      AppStateKeys.seriesResume(playlistId, seriesStreamId);
  static String hiddenGroupsKey(int playlistId) =>
      AppStateKeys.hiddenGroups(playlistId);
  static String pinnedGroupsKey(int playlistId) =>
      AppStateKeys.pinnedGroups(playlistId);
  static String epgRefreshIntervalKey(int playlistId) =>
      AppStateKeys.epgRefreshInterval(playlistId);

  static const String playerBufferSecondsKey = AppStateKeys.playerBufferSeconds;
  static const String vodPreBufferEnabledKey = AppStateKeys.vodPreBufferEnabled;
  static const String vodPreBufferTargetSecondsKey =
      AppStateKeys.vodPreBufferTargetSeconds;
  static const String forceStereoEnabledKey = AppStateKeys.forceStereoEnabled;
  static const String preferredAudioLanguageKey =
      AppStateKeys.preferredAudioLanguage;
  static const String debugModeEnabledKey = AppStateKeys.debugModeEnabled;
  static const String streamingAutoFallbackEnabledKey =
      AppStateKeys.streamingAutoFallbackEnabled;
  static const String streamingShowDiagnosisOnErrorKey =
      AppStateKeys.streamingShowDiagnosisOnError;
  static const String inactivePlaylistIdsKey = AppStateKeys.inactivePlaylistIds;
  static const String appearanceAccentHueKey = AppStateKeys.appearanceAccentHue;
  static const String appearanceSurfaceToneKey =
      AppStateKeys.appearanceSurfaceTone;
  static const String categoryPaneWidthKey = AppStateKeys.categoryPaneWidth;
  static const String hiddenShellTabsKey = AppStateKeys.hiddenShellTabs;

  Future<double> getAppearanceAccentHue({double defaultHue = 170}) =>
      _appearance.getAccentHue(defaultHue: defaultHue);
  Future<void> setAppearanceAccentHue(double hue) =>
      _appearance.setAccentHue(hue);
  Future<double> getAppearanceSurfaceTone({double defaultTone = 0.5}) =>
      _appearance.getSurfaceTone(defaultTone: defaultTone);
  Future<void> setAppearanceSurfaceTone(double tone) =>
      _appearance.setSurfaceTone(tone);

  Future<int> getPlayerBufferSeconds({int defaultSeconds = 15}) =>
      _playback.getBufferSeconds(defaultSeconds: defaultSeconds);
  Future<void> setPlayerBufferSeconds(int seconds) =>
      _playback.setBufferSeconds(seconds);
  Future<bool> getVodPreBufferEnabled({bool defaultEnabled = true}) =>
      _playback.getVodPreBufferEnabled(defaultEnabled: defaultEnabled);
  Future<void> setVodPreBufferEnabled(bool enabled) =>
      _playback.setVodPreBufferEnabled(enabled);
  Future<int> getVodPreBufferTargetSeconds({int defaultSeconds = 90}) =>
      _playback.getVodPreBufferTargetSeconds(defaultSeconds: defaultSeconds);
  Future<void> setVodPreBufferTargetSeconds(int seconds) =>
      _playback.setVodPreBufferTargetSeconds(seconds);
  Future<bool> getForceStereoEnabled({bool defaultEnabled = false}) =>
      _playback.getForceStereoEnabled(defaultEnabled: defaultEnabled);
  Future<void> setForceStereoEnabled(bool enabled) =>
      _playback.setForceStereoEnabled(enabled);
  Future<String?> getPreferredAudioLanguage() =>
      _playback.getPreferredAudioLanguage();
  Future<void> setPreferredAudioLanguage(String? language) =>
      _playback.setPreferredAudioLanguage(language);

  Future<bool> getDebugModeEnabled({bool defaultEnabled = false}) =>
      _diagnostics.getDebugModeEnabled(defaultEnabled: defaultEnabled);
  Future<void> setDebugModeEnabled(bool enabled) =>
      _diagnostics.setDebugModeEnabled(enabled);
  Future<bool> getStreamingAutoFallbackEnabled({bool defaultEnabled = true}) =>
      _diagnostics.getAutoFallbackEnabled(defaultEnabled: defaultEnabled);
  Future<void> setStreamingAutoFallbackEnabled(bool enabled) =>
      _diagnostics.setAutoFallbackEnabled(enabled);
  Future<bool> getStreamingShowDiagnosisOnError({bool defaultEnabled = true}) =>
      _diagnostics.getShowDiagnosisOnError(defaultEnabled: defaultEnabled);
  Future<void> setStreamingShowDiagnosisOnError(bool enabled) =>
      _diagnostics.setShowDiagnosisOnError(enabled);

  Future<Set<int>> getInactivePlaylistIds() =>
      _playlistVisibility.getInactivePlaylistIds();
  Future<bool> isPlaylistActive(int playlistId) =>
      _playlistVisibility.isPlaylistActive(playlistId);
  Future<void> setPlaylistActive(int playlistId, bool active) =>
      _playlistVisibility.setPlaylistActive(playlistId, active);
  Future<Set<String>> getHiddenGroups(int playlistId) =>
      _playlistVisibility.getHiddenGroups(playlistId);
  Future<void> setHiddenGroups(int playlistId, Set<String> hidden) =>
      _playlistVisibility.setHiddenGroups(playlistId, hidden);
  Future<List<String>> getPinnedGroups(int playlistId) =>
      _playlistVisibility.getPinnedGroups(playlistId);
  Future<void> setPinnedGroups(int playlistId, List<String> pinned) =>
      _playlistVisibility.setPinnedGroups(playlistId, pinned);

  Future<ChannelSortMode> getChannelSortMode(int playlistId) =>
      _catalogue.getChannelSortMode(playlistId);
  Future<void> setChannelSortMode(int playlistId, ChannelSortMode mode) =>
      _catalogue.setChannelSortMode(playlistId, mode);
  Future<ChannelSortMode> getAllActiveChannelSortMode() =>
      _catalogue.getAllActiveChannelSortMode();
  Future<void> setAllActiveChannelSortMode(ChannelSortMode mode) =>
      _catalogue.setAllActiveChannelSortMode(mode);

  Future<double> getCategoryPaneWidth({double defaultWidth = 232}) =>
      _layout.getCategoryPaneWidth(defaultWidth: defaultWidth);
  Future<void> setCategoryPaneWidth(double width) =>
      _layout.setCategoryPaneWidth(width);
  Future<Set<String>> getHiddenShellTabs() => _layout.getHiddenShellTabs();
  Future<void> setHiddenShellTabs(Set<String> tabKinds) =>
      _layout.setHiddenShellTabs(tabKinds);

  Future<bool> isEpgReminderDismissed(int playlistId) =>
      _epgReminder.isDismissed(playlistId);
  Future<void> setEpgReminderDismissed(int playlistId, bool dismissed) =>
      _epgReminder.setDismissed(playlistId, dismissed);
  Future<void> clearEpgReminderDismissed(int playlistId) =>
      _epgReminder.setDismissed(playlistId, false);

  Future<EpgRefreshInterval> getEpgRefreshInterval(int playlistId) =>
      _epgRefreshInterval.getInterval(playlistId);
  Future<void> setEpgRefreshInterval(
    int playlistId,
    EpgRefreshInterval interval,
  ) => _epgRefreshInterval.setInterval(playlistId, interval);
  Future<void> clearEpgRefreshInterval(int playlistId) =>
      _epgRefreshInterval.clearInterval(playlistId);

  Future<SeriesResumeState?> getSeriesResume(
    int playlistId,
    String seriesStreamId,
  ) => _seriesResume.get(playlistId, seriesStreamId);
  Future<void> setSeriesResume(
    int playlistId,
    String seriesStreamId,
    SeriesResumeState state,
  ) => _seriesResume.set(playlistId, seriesStreamId, state);
  Future<void> clearSeriesResume(int playlistId, String seriesStreamId) =>
      _seriesResume.clear(playlistId, seriesStreamId);
}
