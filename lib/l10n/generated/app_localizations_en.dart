// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Lunarr Player';

  @override
  String get globalSearchHint => 'Search channels, movies, and series…';

  @override
  String get globalSearchClearTooltip => 'Clear search';

  @override
  String get globalSearchSemanticsLabel => 'Global search';

  @override
  String get globalSearchUnavailable => 'Search is unavailable';

  @override
  String globalSearchIndexBuildingProgress(int ready, int total) {
    return 'Building search index… $ready/$total';
  }

  @override
  String get globalSearchLoading => 'Loading search…';

  @override
  String get globalSearchNoResults => 'No results';

  @override
  String get globalSearchOpenHint => 'Open';

  @override
  String get globalSearchFilterAll => 'All';

  @override
  String get globalSearchFilterChannels => 'Channels';

  @override
  String get globalSearchFilterCategories => 'Categories';

  @override
  String globalSearchIndexProgressSemantics(int ready, int total) {
    return 'Search index: $ready of $total playlists';
  }

  @override
  String globalSearchIndexRetrySemantics(int count) {
    return 'Search index: $count incomplete playlists. Retry';
  }

  @override
  String globalSearchIndexIncompletePlaylists(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count playlists are not fully indexed',
      one: '1 playlist is not fully indexed',
    );
    return '$_temp0';
  }

  @override
  String get globalSearchRetry => 'Retry';

  @override
  String get globalSearchEpgLoading => 'Loading EPG…';

  @override
  String get globalSearchEpgUnavailable => 'EPG unavailable';

  @override
  String globalSearchEpgNow(String title) {
    return 'Now: $title';
  }

  @override
  String get globalSearchEpgNone => 'No EPG';

  @override
  String globalSearchResultSemantics(String title, String metadata) {
    return '$title · $metadata';
  }

  @override
  String get playlistMenuTitle => 'Playlists';

  @override
  String get playlistMenuAdd => 'Add playlist';

  @override
  String get playlistMenuAllActiveSelection => 'All active playlists';

  @override
  String get playlistMenuChoose => 'Choose playlist';

  @override
  String get playlistMenuStatusActive => 'Active';

  @override
  String get playlistMenuStatusInactive => 'Inactive';

  @override
  String get playlistMenuAllLabel => 'All';

  @override
  String get playlistMenuActivePlaylistsSubtitle => 'Active playlists';

  @override
  String get playlistMenuSyncing => 'Syncing…';

  @override
  String get playlistMenuSyncFailed => 'Sync failed';

  @override
  String get playlistMenuSyncTooltip => 'Sync playlist';

  @override
  String get playlistMenuManageTooltip => 'Manage playlist';

  @override
  String playlistDialogCreateFailed(String error) {
    return 'Could not create playlist: $error';
  }

  @override
  String get playlistDialogAddTitle => 'Add playlist';

  @override
  String get playlistDialogCancel => 'Cancel';

  @override
  String get playlistDialogAddAndSync => 'Add and sync';

  @override
  String playlistDialogEditTitle(String type) {
    return 'Edit $type playlist';
  }

  @override
  String get playlistDialogNameField => 'Name';

  @override
  String get playlistDialogHostField => 'Host';

  @override
  String get playlistDialogUrlOrFileField => 'URL or file path';

  @override
  String get playlistDialogUsernameField => 'Username';

  @override
  String get playlistDialogPasswordField => 'Password';

  @override
  String get playlistDialogAutomaticUrlTitle => 'Detected automatically';

  @override
  String get playlistDialogNoAutomaticUrl =>
      'No URL was detected from the source.';

  @override
  String get playlistDialogEpgOverrideField => 'EPG override (optional)';

  @override
  String get playlistDialogEpgOverrideHint =>
      'Leave empty to use the automatic URL';

  @override
  String playlistDialogEffectiveUrl(String url) {
    return 'Effective: $url';
  }

  @override
  String get playlistDialogSaving => 'Saving…';

  @override
  String get playlistDialogSave => 'Save';

  @override
  String playlistHubLoadError(String error) {
    return 'Failed to load playlists: $error';
  }

  @override
  String get playlistHubTitle => 'Playlists';

  @override
  String get playlistHubSubtitle =>
      'Activate, sync, and manage each playlist separately.';

  @override
  String get playlistHubAdd => 'Add playlist';

  @override
  String get playlistHubCategoryVisibilityTitle => 'Category visibility';

  @override
  String get playlistHubCategoryVisibilitySubtitle =>
      'Pin what matters, hide what you do not need, and keep the same order everywhere.';

  @override
  String get playlistHubSyncToLoadCategories =>
      'Sync the playlist to load categories.';

  @override
  String get playlistHubVisibleCategoriesSection => 'Visible categories';

  @override
  String get playlistHubHiddenCategoriesSection => 'Hidden categories';

  @override
  String get playlistHubDeleteTitle => 'Delete playlist?';

  @override
  String playlistHubDeleteBody(String name) {
    return 'The playlist “$name” and its local data will be removed.';
  }

  @override
  String get playlistHubDeleteCancel => 'Cancel';

  @override
  String get playlistHubDeleteConfirm => 'Delete';

  @override
  String playlistHubDeleteSuccess(String name) {
    return 'Playlist “$name” deleted.';
  }

  @override
  String playlistHubDeleteFailure(String error) {
    return 'Delete failed: $error';
  }

  @override
  String get playlistHubContentFilterAll => 'All';

  @override
  String get playlistHubContentFilterLive => 'Live';

  @override
  String get playlistHubContentFilterVod => 'VOD';

  @override
  String get playlistHubContentFilterSeries => 'Series';

  @override
  String get playlistHubEmptyCategoriesAll =>
      'No categories found in this playlist.';

  @override
  String get playlistHubEmptyCategoriesLive =>
      'No live categories found in this playlist.';

  @override
  String get playlistHubEmptyCategoriesVod =>
      'No VOD categories found in this playlist.';

  @override
  String get playlistHubEmptyCategoriesSeries =>
      'No series categories found in this playlist.';

  @override
  String get playlistHubStatusInactive => 'Inactive';

  @override
  String get playlistHubStatusActive => 'Active';

  @override
  String get playlistHubStatusSyncing => 'Syncing…';

  @override
  String get playlistHubStatusEpgSyncing => 'EPG syncing…';

  @override
  String get playlistHubStatusEpgError => 'EPG error';

  @override
  String get playlistHubStatusEpgReady => 'EPG ready';

  @override
  String playlistHubStatusEpgInterval(String interval) {
    return 'EPG $interval';
  }

  @override
  String get playlistHubSyncTooltip => 'Sync playlist';

  @override
  String get playlistHubMoreActionsTooltip => 'More playlist actions';

  @override
  String get playlistHubSyncAction => 'Sync playlist';

  @override
  String get playlistHubNoEpgUrl => 'No EPG URL configured';

  @override
  String get playlistHubRetryEpgAction => 'Retry EPG';

  @override
  String get playlistHubSyncEpgAction => 'Sync EPG';

  @override
  String get playlistHubManageAction => 'Manage';

  @override
  String get playlistHubEditAction => 'Edit';

  @override
  String get playlistHubDeleteAction => 'Delete';

  @override
  String get playlistHubAutomaticEpgTitle => 'Automatically sync EPG';

  @override
  String get playlistHubEpgIntervalManual => 'Manual';

  @override
  String get playlistHubEpgIntervalHours6 => 'Every 6 hours';

  @override
  String get playlistHubEpgIntervalHours12 => 'Every 12 hours';

  @override
  String get playlistHubEpgIntervalHours24 => 'Every 24 hours';

  @override
  String get playlistHubCategoryVisibleDescription =>
      'Visible in all category sidebars';

  @override
  String get playlistHubCategoryHiddenDescription =>
      'Hidden from sidebar lists';

  @override
  String get playlistHubUnpinCategoryTooltip => 'Unpin category';

  @override
  String get playlistHubPinCategoryTooltip => 'Pin category';

  @override
  String get playlistHubSummaryVisible => 'Visible';

  @override
  String get playlistHubSummaryPinned => 'Pinned';

  @override
  String get playlistHubSummaryHidden => 'Hidden';

  @override
  String get playlistHubSummaryHiddenPinned => 'Hidden pinned';

  @override
  String get playlistHubHideAllCategories => 'Hide all';

  @override
  String get playlistHubHideLiveCategories => 'Hide live categories';

  @override
  String get playlistHubHideVodCategories => 'Hide VOD categories';

  @override
  String get playlistHubHideSeriesCategories => 'Hide series categories';

  @override
  String get playlistHubShowAllCategories => 'Show all';

  @override
  String get playlistHubShowLiveCategories => 'Show live categories';

  @override
  String get playlistHubShowVodCategories => 'Show VOD categories';

  @override
  String get playlistHubShowSeriesCategories => 'Show series categories';

  @override
  String get playlistHubEmptyTitle => 'No playlists yet';

  @override
  String get playlistHubEmptySubtitle =>
      'Add your first source and manage it here.';

  @override
  String get diagnosticsConsoleTitle => 'SYSTEM REAL-TIME DIAGNOSTICS';

  @override
  String get diagnosticsConsoleClear => 'Clear';

  @override
  String get diagnosticsConsoleKeyboardHelp =>
      'Press [Space] to play or pause, [F] for fullscreen, [+/-] for volume, and [Arrow keys] to change channels.';

  @override
  String get channelFavoriteRemove => 'Remove from favorites';

  @override
  String get channelFavoriteAdd => 'Add to favorites';

  @override
  String get audioTrackChooseTooltip => 'Choose audio track';

  @override
  String get audioTrackNoneDetectedTooltip => 'No audio tracks detected';

  @override
  String get audioTrackAutomatic => 'Auto';

  @override
  String get playerEmptyTitle => 'Select a channel to play';

  @override
  String get playerEmptySubtitle =>
      'Select a channel from the list or use the arrow keys.';

  @override
  String get playbackAudioRawNone => 'No raw audio tracks detected';

  @override
  String get playbackAudioNoneSelectable =>
      'Audio tracks detected, but none are currently selectable';

  @override
  String playbackAudioTrackCounts(int rawCount, int selectableCount) {
    return '$rawCount raw / $selectableCount selectable';
  }

  @override
  String get playbackAudioNotExposed =>
      'Audio track not exposed by stream or demuxer';

  @override
  String get playbackAudioNone => 'None';

  @override
  String get playbackInfoTitle => 'Playback information';

  @override
  String get playbackInfoCloseTooltip => 'Close';

  @override
  String get playbackInfoTitleLabel => 'Title';

  @override
  String get playbackInfoGroupLabel => 'Group';

  @override
  String get playbackInfoTypeLabel => 'Type';

  @override
  String get playbackInfoResolutionLabel => 'Resolution';

  @override
  String get playbackInfoVideoFormatLabel => 'Video format';

  @override
  String get playbackInfoAudioTrackLabel => 'Audio track';

  @override
  String get playbackInfoAudioTrackStatusLabel => 'Audio track status';

  @override
  String get playbackInfoAudioDecodedLabel => 'Audio decoded';

  @override
  String get playbackInfoAudioFormatLabel => 'Audio format';

  @override
  String get playbackInfoAudioChannelsLabel => 'Audio channels';

  @override
  String get playbackInfoAudioHintLabel => 'Audio note';

  @override
  String get playbackInfoSampleRateLabel => 'Sample rate';

  @override
  String get playbackInfoAudioBitrateLabel => 'Audio bitrate';

  @override
  String get playbackInfoContainerLabel => 'Container';

  @override
  String get playbackInfoPositionLabel => 'Position';

  @override
  String get playbackInfoDurationLabel => 'Duration';

  @override
  String get playbackInfoDemuxerBufferLabel => 'Buffer (demuxer)';

  @override
  String get playbackInfoBufferedUntilLabel => 'Buffered until';

  @override
  String get playbackInfoStatusLabel => 'Status';

  @override
  String get playbackInfoYes => 'Yes';

  @override
  String get playbackInfoNo => 'No';

  @override
  String get playbackInfoBuffering => 'Buffering…';

  @override
  String get playbackInfoPlaying => 'Playing';

  @override
  String get playbackInfoPaused => 'Paused';

  @override
  String get playbackInfoTypeVod => 'Movie (VOD)';

  @override
  String get playbackInfoTypeSeries => 'Series / episode';

  @override
  String get playbackInfoTypeLive => 'Live TV';

  @override
  String episodeCardSemantics(String title) {
    return 'Episode: $title';
  }

  @override
  String movieCardSemantics(String title) {
    return 'Movie: $title';
  }

  @override
  String seriesCardSemantics(String title) {
    return 'Series: $title';
  }

  @override
  String get epgNowMarkerSemantics => 'Now, current time in the programme';

  @override
  String get epgNowMarkerLabel => 'NOW';

  @override
  String get epgToolbarTitle => 'TV PROGRAMME';

  @override
  String get epgToolbarNow => 'Now';

  @override
  String get epgToolbarJumpToNowTooltip => 'Go to the current time';

  @override
  String get epgToolbarBackTwoHoursTooltip => 'Go back two hours';

  @override
  String get epgToolbarForwardTwoHoursTooltip => 'Go forward two hours';

  @override
  String get epgToolbarBackOneDayTooltip => 'Go back one day';

  @override
  String get epgToolbarForwardOneDayTooltip => 'Go forward one day';

  @override
  String get epgToolbarZoomOutTooltip => 'Zoom out the timeline';

  @override
  String get epgToolbarZoomInTooltip => 'Zoom in the timeline';

  @override
  String get epgToolbarResetZoomTooltip => 'Reset the timeline to 100 percent';

  @override
  String get playlistFormTitle => 'ADD PLAYLIST';

  @override
  String get playlistFormDescription =>
      'Create a new source and keep the flow focused on setup, sync, and playback.';

  @override
  String get playlistFormNameLabel => 'Name';

  @override
  String get playlistFormNameHint => 'My IPTV list';

  @override
  String get playlistFormUrlOrFileLabel => 'URL or file path';

  @override
  String get playlistFormHostLabel => 'Host';

  @override
  String get playlistFormUsernameLabel => 'Username';

  @override
  String get playlistFormPasswordLabel => 'Password';

  @override
  String get playlistFormEpgOverrideLabel => 'EPG override (optional)';

  @override
  String get playlistFormEpgOverrideHint =>
      'Leave empty to use the automatic URL';

  @override
  String get playlistFormWorking => 'Working…';

  @override
  String get playlistFormAddAndSync => 'Add and sync';

  @override
  String get appearanceTitle => 'Appearance';

  @override
  String get appearanceDescription =>
      'Adjust the accent and neutral surfaces independently.';

  @override
  String get appearanceRestoreDefaults => 'Restore defaults';

  @override
  String get appearanceAccentColor => 'Accent color';

  @override
  String get appearanceNeutralSurfaceTone => 'Neutral gray / surface tone';

  @override
  String appearanceDegreesSemantics(int value) {
    return '$value degrees';
  }

  @override
  String appearancePercentSemantics(int value) {
    return '$value percent';
  }

  @override
  String get appearancePreviewLiveTv => 'Live TV';

  @override
  String get appearancePreviewLibrary => 'Library';

  @override
  String get appearancePreviewSelect => 'Select';

  @override
  String get debugModeTitle => 'DEBUG MODE';

  @override
  String get debugModeDescription =>
      'Shows the Diagnostics / Logs tab and keeps collecting logs even when hidden.';

  @override
  String get debugModeDiagnosticsOn => 'Diagnostics on';

  @override
  String get debugModeHidden => 'Hidden';

  @override
  String get debugModeEnabled => 'Enabled';

  @override
  String get debugModeDisabled => 'Disabled';

  @override
  String get settingsSectionsTitle => 'Sections';

  @override
  String get settingsSectionGeneral => 'General';

  @override
  String get settingsSectionPlayback => 'Playback';

  @override
  String get settingsSectionDiscovery => 'Discovery';

  @override
  String get settingsSectionNavigation => 'Tabs and navigation';

  @override
  String get settingsSectionAppearance => 'Appearance';

  @override
  String get favoriteSaveFailed => 'Could not save favorite.';

  @override
  String get favoritesLoadFailed => 'Could not load favorites';

  @override
  String get favoritesNoPlaylistTitle => 'No playlist selected';

  @override
  String get favoritesNoPlaylistSubtitle =>
      'Select a playlist to see your favorites.';

  @override
  String get favoritesEmptyTitle => 'No live favorites yet';

  @override
  String get favoritesEmptySubtitle =>
      'Favorites from your active playlist will appear here.';

  @override
  String favoriteChannelSemantics(String title) {
    return 'Favorite: $title';
  }

  @override
  String get favoriteIconSemantics => 'Favorite';

  @override
  String get favoritePlayLiveSemantics => 'Play live';

  @override
  String get watchLaterRemove => 'Remove from Watch Later';

  @override
  String get watchLaterSave => 'Save for later';

  @override
  String get watchLaterLoadFailed => 'Could not load Watch Later';

  @override
  String get watchLaterNoPlaylistSubtitle => 'Select an active playlist first.';

  @override
  String get watchLaterEmptyTitle => 'Nothing saved for later yet';

  @override
  String get watchLaterEmptySubtitle =>
      'Bookmark movies or series to keep them here.';

  @override
  String get catalogNoPlaylistSubtitle =>
      'Select a playlist in the Playlists tab or Settings.';

  @override
  String get catalogResetFilters => 'Reset filters';

  @override
  String get catalogSyncPlaylist => 'Sync playlist';

  @override
  String get catalogSyncingPlaylist => 'Syncing playlist…';

  @override
  String get catalogGenresTitle => 'Genres';

  @override
  String get catalogSyncAction => 'Sync';

  @override
  String get vodLoadFailed => 'Could not load movies';

  @override
  String get vodNoSearchResults => 'No movies match your search';

  @override
  String get vodNoVisibleMovies => 'No movies visible';

  @override
  String get vodNoMoviesFound => 'No movies found';

  @override
  String get vodClearSearchSubtitle =>
      'Clear the search field to show all movies again.';

  @override
  String get vodHiddenByFiltersSubtitle =>
      'Your VOD catalogue is loaded, but filters or hidden categories are hiding the visible list.';

  @override
  String get vodSyncSubtitle => 'Sync your Xtream playlist to load VOD movies.';

  @override
  String get vodToolbarTitle => 'VOD MOVIES';

  @override
  String get seriesLoadFailed => 'Could not load series';

  @override
  String get seriesNoSearchResults => 'No series match your search';

  @override
  String get seriesNoVisibleSeries => 'No series visible';

  @override
  String get seriesNoSeriesFound => 'No series found';

  @override
  String get seriesClearSearchSubtitle =>
      'Clear the search field to show all series again.';

  @override
  String get seriesHiddenByFiltersSubtitle =>
      'Your series catalogue is loaded, but filters or hidden categories are hiding the visible list.';

  @override
  String get seriesSyncSubtitle => 'Sync your Xtream playlist to load series.';

  @override
  String get seriesToolbarTitle => 'SERIES';

  @override
  String get epgNoSearchResults => 'No channels match your search';

  @override
  String epgClearSearchSubtitle(int count) {
    return 'Clear the search field to show all $count channels again.';
  }

  @override
  String get epgNoChannelsTitle => 'No channels loaded';

  @override
  String get epgNoChannelsSubtitle =>
      'Select a playlist and sync channels on the Live tab or in Settings.';

  @override
  String get epgNoDataTitle => 'No EPG data for this time window';

  @override
  String get epgUpdateGuideSubtitle =>
      'Update the TV programme guide for your active playlist.';

  @override
  String get epgConfigureUrlSubtitle =>
      'Configure an EPG URL in Settings or sync an M3U playlist with a url-tvg header.';

  @override
  String get epgUpdateAction => 'Update EPG';

  @override
  String get playbackSettingsTitle => 'PLAYBACK';

  @override
  String get playbackSettingsDescription =>
      'Choose how much content is buffered before live playback starts. Higher values delay startup but reduce stuttering on unstable streams.';

  @override
  String get playbackSettingsLiveBufferLabel => 'Live startup buffer';

  @override
  String get playbackSettingsVodBufferDescription =>
      'VOD pre-buffering loads media before playback for smoother seeking. Higher values require more time and bandwidth.';

  @override
  String get playbackSettingsVodBufferLabel => 'VOD pre-buffer';

  @override
  String get playbackSettingsForceStereoTitle => 'Force stereo';

  @override
  String get playbackSettingsForceStereoDescription =>
      'Helps with external sound cards, mixing consoles, or channels with multichannel audio.';

  @override
  String get playbackSettingsPreferredLanguageTitle =>
      'Preferred audio language';

  @override
  String get playbackSettingsPreferredLanguageDescription =>
      'When multiple audio tracks are available, this language is preferred.';

  @override
  String get playbackSettingsLanguageAutomatic => 'Automatic';

  @override
  String get playbackSettingsLanguageGerman => 'German';

  @override
  String get playbackSettingsBufferOff => 'Off';

  @override
  String playbackSettingsBufferSeconds(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds seconds',
      one: '1 second',
    );
    return '$_temp0';
  }

  @override
  String playbackSettingsBufferMaximum(int seconds) {
    return '$seconds seconds (maximum)';
  }

  @override
  String seriesPlayEpisode(String title) {
    return 'Play — $title';
  }

  @override
  String get seriesEpisodesTab => 'Episodes';

  @override
  String get commonBackTooltip => 'Back';

  @override
  String get seriesContinueWatching => 'Continue watching';

  @override
  String get seriesContinueAction => 'Continue';

  @override
  String get seriesNoEpisodes => 'No episodes found.';

  @override
  String get channelRefreshFailedRetained =>
      'Channels could not be refreshed. The last loaded channels remain visible.';

  @override
  String get channelLoadFailed => 'Could not load channels';

  @override
  String get channelNoPlaylistSubtitle =>
      'Add and sync a playlist to see channels here.';

  @override
  String get channelNoSearchResults => 'No channels match your search';

  @override
  String get channelNoChannelsFound => 'No channels found';

  @override
  String get channelClearSearchSubtitle =>
      'Clear the search field to show all channels again.';

  @override
  String get channelSyncOrFilterSubtitle =>
      'Sync your playlist or try a different category filter.';

  @override
  String channelSyncFailed(String error) {
    return 'Sync failed: $error';
  }

  @override
  String get channelEpgUpdated => 'EPG updated successfully.';

  @override
  String channelEpgSyncFailed(String error) {
    return 'EPG sync failed: $error';
  }

  @override
  String channelPlaylistCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count playlists',
      one: '1 playlist',
      zero: 'No playlists',
    );
    return '$_temp0';
  }

  @override
  String get channelAllActivePlaylists => 'All active playlists';

  @override
  String get channelLiveTitle => 'LIVE CHANNELS';

  @override
  String get channelUncategorized => 'Uncategorized';

  @override
  String get channelLoading => 'Loading channels…';

  @override
  String get commonRetry => 'Retry';

  @override
  String channelSortTooltip(String mode) {
    return 'Sort: $mode';
  }

  @override
  String get channelSortProvider => 'Provider order';

  @override
  String get channelSortAlphabetical => 'Alphabetical';

  @override
  String get channelSortNumber => 'Channel number';

  @override
  String channelEpgNow(String title) {
    return 'Now: $title';
  }

  @override
  String get channelEpgLoading => 'Loading EPG…';

  @override
  String get channelNoEpg => 'No EPG';

  @override
  String get channelEpgNotUpdated =>
      'The TV programme guide (EPG) has not been updated yet.';

  @override
  String get channelEpgUpdating => 'Updating…';

  @override
  String get channelEpgUpdateNow => 'Update EPG now';

  @override
  String get commonDismissTooltip => 'Dismiss';

  @override
  String get commonSyncing => 'Syncing…';

  @override
  String get commonSync => 'Sync';

  @override
  String get mediaLibraryMoviesTab => 'Movies';

  @override
  String get mediaLibrarySeriesTab => 'Series';

  @override
  String get mediaLibraryWatchLaterTab => 'Watch Later';

  @override
  String epgAgendaNext(String title) {
    return 'Next: $title';
  }

  @override
  String epgAgendaNow(String title) {
    return 'NOW: $title';
  }

  @override
  String get epgAgendaUnavailable => 'No EPG available';

  @override
  String get epgAgendaNoCurrentProgram => 'No programme currently airing';

  @override
  String epgAgendaChannelSemantics(String name) {
    return 'Channel: $name';
  }

  @override
  String epgAgendaLiveSemantics(String title) {
    return 'LIVE, now playing: $title';
  }

  @override
  String get epgAgendaStartChannel => 'Play channel';

  @override
  String get epgLiveNowSemantics => 'LIVE, now playing';

  @override
  String get commonLiveLabel => 'LIVE';

  @override
  String epgProgramLiveSemantics(String title) {
    return 'Live now: $title';
  }

  @override
  String epgProgramSemantics(String title) {
    return 'Programme: $title';
  }

  @override
  String epgProgramDurationMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes min',
      one: '1 min',
    );
    return '$_temp0';
  }

  @override
  String get epgGridChannelHeader => 'CHANNEL';

  @override
  String epgGridChannelSemantics(String name, String status) {
    return 'Channel: $name. $status';
  }

  @override
  String get epgGridNoProgramme => 'No programme';

  @override
  String get epgGridNoEpg => 'No EPG';

  @override
  String get epgTimelineResizeSemantics => 'Adjust time column width';

  @override
  String get epgTimelineResizeHint =>
      'Use the arrow keys to adjust it step by step';

  @override
  String diagnosticsSettingsLoadFailed(String error) {
    return 'Could not load streaming diagnostics settings: $error';
  }

  @override
  String get diagnosticsStreamingTitle => 'PLAYER & STREAMING';

  @override
  String get diagnosticsStreamingSubtitle => 'Advanced diagnostics';

  @override
  String get diagnosticsFallbackOn => 'Fallback on';

  @override
  String get diagnosticsFallbackOff => 'Fallback off';

  @override
  String get diagnosticsAutoFallbackTitle => 'Use fallback automatically';

  @override
  String get diagnosticsAutoFallbackSubtitle =>
      'Automatically try the live fallback matrix before showing an error.';

  @override
  String get diagnosticsShowOnErrorTitle => 'Show diagnostics on error';

  @override
  String get diagnosticsShowOnErrorSubtitle =>
      'Writes a short diagnostic entry to the UI logs when live playback fails to start.';

  @override
  String get diagnosticsCopyLastFailure => 'Copy last failure';

  @override
  String get diagnosticsLastFailureCopied => 'Last streaming failure copied.';

  @override
  String get diagnosticsCopyPlayerLog => 'Copy player log';

  @override
  String get diagnosticsPlayerLogCopied => 'Player log copied.';

  @override
  String get diagnosticsTestStream => 'Test stream';

  @override
  String get diagnosticsStreamCheckFailed => 'Stream check failed.';

  @override
  String get diagnosticsLastFailureTitle => 'Last streaming failure';

  @override
  String get playerPreviousChannelTooltip => 'Previous channel';

  @override
  String playerSeekBackwardTooltip(int seconds) {
    return 'Skip back $seconds seconds';
  }

  @override
  String playerSeekForwardTooltip(int seconds) {
    return 'Skip forward $seconds seconds';
  }

  @override
  String get playerPlayTooltip => 'Play';

  @override
  String get playerPauseTooltip => 'Pause';

  @override
  String get playerStopTooltip => 'Stop';

  @override
  String get playerNextChannelTooltip => 'Next channel';

  @override
  String get playerPlaybackInfoTooltip => 'Playback information';

  @override
  String get playerFullscreenTooltip => 'Fullscreen';

  @override
  String playerNowPlaying(String title) {
    return 'Now playing: $title';
  }

  @override
  String playerPositionSemantics(String position) {
    return 'Position $position';
  }

  @override
  String playerBufferedAhead(String duration) {
    return '$duration ahead';
  }

  @override
  String get playerBuffering => 'Buffering…';

  @override
  String get playerLoading => 'Loading…';

  @override
  String playerStartupBufferProgress(String current, String target) {
    return 'Startup buffer $current / $target';
  }

  @override
  String get playerStartupBufferBuilding => 'Building startup buffer…';

  @override
  String playerBuffered(String duration) {
    return '$duration buffered';
  }

  @override
  String get playerStabilizingLive => 'Stabilizing live connection…';

  @override
  String get playerLiveInstantStart => 'Live — instant start';

  @override
  String get playerLiveRollingBuffer => 'Live — rolling buffer active';

  @override
  String playerStartsAtBuffer(String target) {
    return 'Starts at $target';
  }

  @override
  String get playerLiveCacheActive => 'Live cache active';

  @override
  String playerTargetBuffer(String target) {
    return 'Target buffer $target';
  }

  @override
  String playerMaximumBuffer(String duration) {
    return 'Max $duration';
  }

  @override
  String get playerVolumeSemantics => 'Volume';

  @override
  String get playerUnmuteTooltip => 'Unmute';

  @override
  String get playerMuteTooltip => 'Mute';

  @override
  String playerVolumePercentSemantics(int percent) {
    return 'Volume $percent percent';
  }

  @override
  String get playerNoChannelSelected => 'No channel selected';

  @override
  String get playerStatusIdle => 'IDLE';

  @override
  String get playerStatusStabilizing => 'STABILIZING';

  @override
  String get playerStatusWarmingUp => 'WARMING UP';

  @override
  String get playerStatusBuffering => 'BUFFERING';

  @override
  String get playerStatusLive => 'LIVE';

  @override
  String get playerStatusPaused => 'PAUSED';

  @override
  String get playerExitFullscreenHint => 'Press F or Esc to exit fullscreen';

  @override
  String get playerLivePlaybackTitle => 'LIVE PLAYBACK';

  @override
  String get playerStatusError => 'ERROR';

  @override
  String get playerStatusReady => 'READY';

  @override
  String get playerStatusConnecting => 'CONNECTING';

  @override
  String get playerStatusOnAir => 'ON AIR';

  @override
  String get playerSelectChannelTitle => 'Select a channel';

  @override
  String get playerSelectChannelFullscreenSubtitle =>
      'Exit fullscreen (F / Esc) and select a channel from the list.';

  @override
  String get playerPlaybackFailedTitle => 'Playback failed';

  @override
  String get playerVideoInitializationFailed =>
      'Could not initialize video output.';

  @override
  String get playbackPrepEpisodeTitle => 'Prepare episode';

  @override
  String get playbackPrepMovieTitle => 'Prepare movie';

  @override
  String get playbackPrepEpisodeSubtitle =>
      'Pre-buffered start for a smoother episode handoff.';

  @override
  String get playbackPrepMovieSubtitle =>
      'Pre-buffered start for smoother seeking and faster resume.';

  @override
  String playbackPrepBufferingProgress(int percent) {
    return 'Buffering… $percent%';
  }

  @override
  String get playbackPrepOpeningStream => 'Opening stream…';

  @override
  String get playbackPrepCompleted => 'Preparation complete';

  @override
  String get playbackPrepReady => 'Ready to play';

  @override
  String playbackPrepDetectedMedia(String resolution, String container) {
    return 'Detected: $resolution$container';
  }

  @override
  String get playbackPrepEpisodeExplanation =>
      'Buffer the episode before playback for smoother seeking and resume.';

  @override
  String get playbackPrepMovieExplanation =>
      'Buffer before playback for smoother forward and backward seeking.';

  @override
  String get playbackPrepLoadingAction => 'Loading…';

  @override
  String get playbackPrepPrepareAction => 'Prepare';

  @override
  String get playbackPrepStartAction => 'Start playback';

  @override
  String get playbackPrepStartImmediatelyAction => 'Start immediately';

  @override
  String playbackPrepStartPosition(String position) {
    return 'Start at $position';
  }

  @override
  String get playbackPrepEpisodeDetail =>
      'Buffer the episode before playback for smoother seeking within the episode.';

  @override
  String get playbackPrepMovieDetail =>
      'Buffer before playback for smoother forward and backward seeking.';

  @override
  String get playbackPrepToggleTitle => 'Pre-buffer';

  @override
  String playbackPrepToggleSubtitle(int seconds) {
    return 'Loads approximately $seconds seconds before playback (Settings → Playback)';
  }

  @override
  String get windowMinimizeTooltip => 'Minimize';

  @override
  String get windowMaximizeRestoreTooltip => 'Maximize / Restore';

  @override
  String get windowCloseTooltip => 'Close';

  @override
  String get paneCategories => 'Categories';

  @override
  String get paneChannels => 'Channel list';

  @override
  String paneCollapseAction(String pane) {
    return 'Collapse $pane';
  }

  @override
  String paneExpandAction(String pane) {
    return 'Expand $pane';
  }

  @override
  String get categoryPaneResizeLabel => 'Resize category pane';

  @override
  String get categoryPaneResizeHint => 'Drag to resize; double-click to reset';

  @override
  String get stepperDecreaseValue => 'Decrease value';

  @override
  String get stepperIncreaseValue => 'Increase value';

  @override
  String get databaseFatalSemanticLabel =>
      'Database connection interrupted. Restart the application.';

  @override
  String get databaseFatalMessage =>
      'Database connection interrupted — please restart the application.';

  @override
  String get comingSoonTitle => 'Feature — Coming Soon';

  @override
  String get comingSoonDescription =>
      'This section is planned for a future milestone.';

  @override
  String get playbackSettingsLanguageEnglish => 'English';

  @override
  String get playbackSettingsSeekIntervalLabel => 'Skip interval';

  @override
  String playbackSettingsSeconds(int seconds) {
    return '$seconds seconds';
  }

  @override
  String get playbackSettingsTrickplayTitle => 'Timeline previews';

  @override
  String get playbackSettingsTrickplayDescription =>
      'Show Jellyfin preview images while scrubbing.';

  @override
  String get playbackSettingsMediaSegmentsLabel => 'Intro and recap skipping';

  @override
  String get playbackSettingsMediaSegmentsOff => 'Off';

  @override
  String get playbackSettingsMediaSegmentsButton => 'Show skip button';

  @override
  String get playbackSettingsMediaSegmentsAutomatic => 'Skip automatically';

  @override
  String get playbackSettingsAutoplayTitle => 'Play next episode automatically';

  @override
  String get playbackSettingsAutoplayDescription =>
      'Show an endcard and start the next episode after a countdown.';

  @override
  String get playbackSettingsEndcardCountdownLabel => 'Endcard countdown';

  @override
  String get playbackSettingsLanguageFrench => 'Français';

  @override
  String get playbackSettingsLanguageSpanish => 'Español';

  @override
  String get playbackSettingsLanguageItalian => 'Italiano';

  @override
  String get playbackSettingsLanguagePortuguese => 'Português';

  @override
  String get playbackSettingsLanguageTurkish => 'Türkçe';

  @override
  String get playbackSettingsLanguageRussian => 'Русский';

  @override
  String get shellTabLiveTitle => 'Live TV';

  @override
  String get shellTabLiveSubtitle =>
      'Watch live channels — select a playlist and tap to play.';

  @override
  String get shellTabMediaLibraryTitle => 'Media Library';

  @override
  String get shellTabMediaLibrarySubtitle =>
      'Movies, series, and Watch Later in one shared media library.';

  @override
  String get shellTabJellyfinTitle => 'Jellyfin';

  @override
  String get shellTabJellyfinSubtitle => 'Your personal media library';

  @override
  String get jellyfinConnectTitle => 'Connect to Jellyfin';

  @override
  String get jellyfinConnectDescription =>
      'Enter your Jellyfin server address to get started.';

  @override
  String get jellyfinServerLabel => 'Server';

  @override
  String get jellyfinServerHint => 'http://server:8096';

  @override
  String get jellyfinCheckConnection => 'Check connection';

  @override
  String get jellyfinConnecting => 'Connecting…';

  @override
  String get jellyfinConnected => 'Connected';

  @override
  String get jellyfinCheckingServer => 'Checking server…';

  @override
  String get jellyfinServerVerifiedLabel => 'Server verified';

  @override
  String jellyfinServerVersionLabel(String version) {
    return 'Server version $version';
  }

  @override
  String get jellyfinUsernameLabel => 'Username';

  @override
  String get jellyfinPasswordLabel => 'Password';

  @override
  String get jellyfinSignIn => 'Sign in';

  @override
  String get jellyfinSignOut => 'Sign out';

  @override
  String get jellyfinHttpWarning =>
      'This server uses HTTP. Your password and Jellyfin session token will be sent without transport encryption.';

  @override
  String get jellyfinHttpDialogTitle => 'Unencrypted Jellyfin connection';

  @override
  String get jellyfinHttpDialogMessage =>
      'This server uses HTTP. Continue only if you trust the network. Your password and session token can be intercepted.';

  @override
  String get jellyfinHttpCancel => 'Cancel';

  @override
  String get jellyfinHttpContinue => 'Continue over HTTP';

  @override
  String jellyfinSignedInAs(String username) {
    return 'Signed in as $username';
  }

  @override
  String get jellyfinErrorInvalidUrl =>
      'Enter a valid server address with http:// or https://.';

  @override
  String get jellyfinErrorDns => 'The server host could not be resolved.';

  @override
  String get jellyfinErrorConnectionRefused =>
      'The connection was refused by the server.';

  @override
  String get jellyfinErrorHostUnreachable => 'The server is not reachable.';

  @override
  String get jellyfinErrorTimeout => 'The connection timed out.';

  @override
  String get jellyfinErrorTls =>
      'The secure connection failed. Check the server certificate.';

  @override
  String get jellyfinErrorNotJellyfin =>
      'This address does not look like a Jellyfin server.';

  @override
  String get jellyfinErrorInvalidCredentials =>
      'Incorrect username or password.';

  @override
  String get jellyfinErrorUnknown => 'The connection failed.';

  @override
  String get jellyfinContinueWatching => 'Continue watching';

  @override
  String get jellyfinNextUp => 'Next up';

  @override
  String get jellyfinRecentlyAdded => 'Recently added';

  @override
  String get jellyfinLibraries => 'Libraries';

  @override
  String get jellyfinOverview => 'Overview';

  @override
  String get jellyfinHomeEmptyTitle => 'Nothing here yet';

  @override
  String get jellyfinHomeEmptySubtitle =>
      'Add media to your Jellyfin libraries and refresh.';

  @override
  String get jellyfinRefreshTooltip => 'Refresh';

  @override
  String get jellyfinLoadFailed => 'Could not load from the Jellyfin server.';

  @override
  String get jellyfinLibraryEmpty => 'This library is empty.';

  @override
  String get jellyfinPlay => 'Play';

  @override
  String get jellyfinTrailer => 'Trailer';

  @override
  String get jellyfinFavorite => 'Favorite';

  @override
  String get jellyfinRemoveFavorite => 'Remove favorite';

  @override
  String get jellyfinMarkWatched => 'Mark watched';

  @override
  String get jellyfinMarkUnwatched => 'Mark unwatched';

  @override
  String get jellyfinStatusSaveFailed => 'Could not update the item status.';

  @override
  String get jellyfinTrailerOpenFailed => 'Could not open the trailer.';

  @override
  String get jellyfinProviderOpenFailed =>
      'Could not open the metadata provider.';

  @override
  String get jellyfinCommunityRating => 'Community';

  @override
  String get jellyfinCriticRating => 'Critics';

  @override
  String get jellyfinImdbProviderLabel => 'IMDb';

  @override
  String get jellyfinTmdbProviderLabel => 'TMDb';

  @override
  String jellyfinOpenProviderTooltip(String provider) {
    return 'Open $provider';
  }

  @override
  String jellyfinImdbProvider(String id) {
    return 'IMDb $id';
  }

  @override
  String jellyfinTmdbProvider(String id) {
    return 'TMDb $id';
  }

  @override
  String get jellyfinGenres => 'Genres';

  @override
  String get jellyfinDirectors => 'Directors';

  @override
  String get jellyfinWriters => 'Writers';

  @override
  String get jellyfinStudios => 'Studios';

  @override
  String get jellyfinPlayerFailed => 'Playback could not be started.';

  @override
  String get jellyfinPlayerDirectPlay => 'Direct Play';

  @override
  String get jellyfinPlayerDirectStream => 'Direct Stream';

  @override
  String get jellyfinPlayerTranscode => 'Transcode';

  @override
  String get jellyfinStopTooltip => 'Stop and go back';

  @override
  String get jellyfinVolumeTooltip => 'Volume';

  @override
  String jellyfinVolumePercent(int percent) {
    return '$percent%';
  }

  @override
  String get jellyfinAudioTrackTooltip => 'Audio track';

  @override
  String get jellyfinSubtitleTrackTooltip => 'Subtitles';

  @override
  String get jellyfinSubtitleOff => 'Off';

  @override
  String get jellyfinPreviousEpisodeTooltip => 'Previous episode';

  @override
  String get jellyfinNextEpisodeTooltip => 'Next episode';

  @override
  String get jellyfinSkipIntro => 'Skip intro';

  @override
  String get jellyfinSkipRecap => 'Skip recap';

  @override
  String get jellyfinUpNext => 'Up next';

  @override
  String get jellyfinPlayNow => 'Play now';

  @override
  String jellyfinPlayNowCountdown(int seconds) {
    return 'Play now · $seconds';
  }

  @override
  String get jellyfinEndcardCancel => 'Cancel';

  @override
  String get jellyfinShowEpisodesTooltip => 'Show episodes';

  @override
  String get jellyfinHideEpisodesTooltip => 'Hide episodes';

  @override
  String get jellyfinEpisodesTitle => 'Episodes';

  @override
  String get jellyfinNoEpisodes => 'No episodes are available.';

  @override
  String jellyfinEpisodeSemantics(String episodeLabel, String title) {
    return '$episodeLabel, $title';
  }

  @override
  String get jellyfinSeasonSelectorLabel => 'Season';

  @override
  String get jellyfinDurationUnknown => '--:--';

  @override
  String get jellyfinResumeLabel => 'Resume';

  @override
  String jellyfinRuntimeMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String jellyfinRuntimeHours(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String jellyfinSeasonLabel(int number) {
    return 'Season $number';
  }

  @override
  String jellyfinSeasonEpisodeLabel(int season, int episode) {
    return 'S$season E$episode';
  }

  @override
  String jellyfinEpisodeLabel(int number) {
    return 'Episode $number';
  }

  @override
  String jellyfinEpisodeNumberLabel(int number) {
    return 'E$number';
  }

  @override
  String jellyfinMetaLine(String year, String runtime) {
    return '$year · $runtime';
  }

  @override
  String jellyfinItemsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String get shellTabFavoritesTitle => 'Favorites';

  @override
  String get shellTabFavoritesSubtitle =>
      'Quick access to your favorite live channels.';

  @override
  String get shellTabPlaylistsTitle => 'Playlists';

  @override
  String get shellTabPlaylistsSubtitle =>
      'Switch playlists and manage which categories are visible.';

  @override
  String get shellTabEpgTitle => 'EPG Guide';

  @override
  String get shellTabEpgSubtitle =>
      'TV program guide for the active playlist — select a show to watch live.';

  @override
  String get shellTabVodTitle => 'VOD Movies';

  @override
  String get shellTabVodSubtitle =>
      'Browse movies from your active playlist — select one to play on the Live tab.';

  @override
  String get shellTabSeriesTitle => 'Series';

  @override
  String get shellTabSeriesSubtitle =>
      'Browse series — open a show for episodes and resume where you left off.';

  @override
  String get shellTabDiagnosticsTitle => 'Diagnostics / Logs';

  @override
  String get shellTabDiagnosticsSubtitle =>
      'Debug-only log console and runtime diagnostics.';

  @override
  String get shellTabSettingsTitle => 'Settings';

  @override
  String get shellTabSettingsSubtitle =>
      'Add, sync, and manage M3U and Xtream playlists.';

  @override
  String get shellFallbackTitle => 'Neural Control Center';

  @override
  String get shellFallbackSubtitle =>
      'Material 3 media workspace (Drift & Riverpod)';

  @override
  String get shellSidebarLabel => 'Sidebar';

  @override
  String get liveStartupBufferOff => 'Off';

  @override
  String liveStartupBufferSeconds(int seconds) {
    return '$seconds seconds';
  }

  @override
  String liveStartupBufferSecondsMaximum(int seconds) {
    return '$seconds seconds (maximum)';
  }

  @override
  String playerPanelError(String error) {
    return 'Player error: $error';
  }

  @override
  String get playerAudioDetectionTitle => 'Detecting audio';

  @override
  String get playerAudioDetectionSubtitle => 'Detecting audio track…';

  @override
  String get playerAudioSynchronizationTitle => 'Synchronizing audio';

  @override
  String get playerAudioSynchronizationSubtitle => 'Stabilizing audio track…';

  @override
  String get playerInstantStartActive => 'Instant start active';

  @override
  String playerStartsAtBufferTarget(String target) {
    return 'Starts at $target buffer';
  }

  @override
  String get playerBuildingLiveBuffer => 'Building live buffer';

  @override
  String get playerPreparingStream => 'Preparing stream';

  @override
  String get playerDetectingAudio => 'Detecting audio…';

  @override
  String get playerEstablishingConnection => 'Establishing connection…';

  @override
  String epgGridNowProgram(String title) {
    return 'Now: $title';
  }

  @override
  String get playbackPrepVideoSurfaceTimeout =>
      'Video output was not ready in time. Please start playback again.';

  @override
  String get globalSearchTargetLive => 'Live TV';

  @override
  String get globalSearchTargetMovies => 'Movies';

  @override
  String get globalSearchTargetSeries => 'Series';

  @override
  String globalSearchCategoryVisibleLabel(
    String category,
    String target,
    String playlist,
  ) {
    return '$category · $target · $playlist';
  }

  @override
  String globalSearchCategoryMetadata(String target, String playlist) {
    return '$target · $playlist';
  }

  @override
  String get playbackAudioMultichannelHint =>
      'Multichannel audio decoded. If no sound is audible, try Force stereo.';

  @override
  String get jellyfinConnectionMenuTitle => 'Jellyfin accounts';

  @override
  String get jellyfinConnectionMenuChoose => 'Choose account';

  @override
  String get jellyfinConnectionMenuEmpty => 'No saved Jellyfin accounts yet.';

  @override
  String get jellyfinConnectionMenuAdd => 'Connect another account';

  @override
  String get shellTabVisibilityTitle => 'Navigation tabs';

  @override
  String get shellTabVisibilityDescription =>
      'Choose which main tabs appear in the sidebar.';

  @override
  String get shellTabVisibilityReset => 'Show all';

  @override
  String get shellTabVisibilitySettingsAlwaysVisible =>
      'Settings always remains visible so you can restore tabs.';

  @override
  String get shellTabHomeTitle => 'Home';

  @override
  String get shellTabHomeSubtitle => 'Discover movies and series';

  @override
  String get discoveryGeneralRecommendations => 'General discovery';

  @override
  String get discoverySearchHint => 'Search movies and series…';

  @override
  String get discoverySearchSemantics => 'Search discovery catalog';

  @override
  String get discoverySearchClearTooltip => 'Clear discovery search';

  @override
  String get discoverySearchTitle => 'Search';

  @override
  String get discoveryBackTooltip => 'Back';

  @override
  String get discoveryHomeTooltip => 'Discovery home';

  @override
  String get discoveryShowAll => 'Show all';

  @override
  String get discoveryShelfPrevious => 'Scroll shelf backward';

  @override
  String get discoveryShelfNext => 'Scroll shelf forward';

  @override
  String discoveryShelfSemantics(String title) {
    return 'Horizontal shelf: $title';
  }

  @override
  String discoverySwitchSource(String source) {
    return 'Switch to $source';
  }

  @override
  String get discoveryOpenTrailer => 'Open trailer';

  @override
  String get discoveryMoreTrailers => 'More videos';

  @override
  String get discoveryTrailerOpenFailed =>
      'The trailer could not be opened in your browser.';

  @override
  String get appearanceAmbientTitle => 'App background';

  @override
  String get appearanceAmbientDescription =>
      'Add a soft, animated Lunarr glow behind the entire app. Player video stays on a neutral black canvas. Reduced Motion freezes the effect.';

  @override
  String get appearanceAmbientEnabled => 'Lunarr background';

  @override
  String get appearanceAmbientPreset => 'Color preset';

  @override
  String get appearanceAmbientPresetLunarr => 'Lunarr';

  @override
  String get appearanceAmbientPresetAurora => 'Aurora';

  @override
  String get appearanceAmbientPresetEmber => 'Ember';

  @override
  String get appearanceAmbientPresetCustom => 'Custom';

  @override
  String get appearanceAmbientHueA => 'First custom hue';

  @override
  String get appearanceAmbientHueB => 'Second custom hue';

  @override
  String get appearanceAmbientIntensity => 'Intensity';

  @override
  String appearanceAmbientPercent(int percent) {
    return '$percent%';
  }

  @override
  String get appearanceAmbientMotion => 'Movement';

  @override
  String get appearanceAmbientMotionSlow => 'Slow';

  @override
  String get appearanceAmbientMotionNormal => 'Normal';

  @override
  String get appearanceAmbientMotionFast => 'Fast';

  @override
  String get appearanceAmbientReset => 'Reset app background';

  @override
  String get discoveryTrendingToday => 'Trending today';

  @override
  String discoveryTrendingItemSemantics(String title) {
    return 'Trending today: $title';
  }

  @override
  String get discoveryPopularMovies => 'Popular movies';

  @override
  String get discoveryPopularSeries => 'Popular series';

  @override
  String get discoveryUpcomingMovies => 'Coming to cinemas';

  @override
  String get discoveryOnTheAir => 'Series on the air';

  @override
  String get discoveryTopRated => 'Top rated';

  @override
  String get discoveryAdultBadge => 'Adult';

  @override
  String get discoveryStaleData => 'Offline copy · may be out of date';

  @override
  String get discoveryRefreshTooltip => 'Refresh discovery';

  @override
  String get discoveryRetry => 'Retry';

  @override
  String get discoverySetupTitle => 'Set up discovery';

  @override
  String get discoverySetupTmdbDescription =>
      'Add a TMDB Read Access Token in Settings to load public movie and series data.';

  @override
  String get discoverySetupSeerrDescription =>
      'Add a Seerr endpoint and administrator API key in Settings to use this source.';

  @override
  String get discoveryOpenSettings => 'Open Settings';

  @override
  String get discoveryNoResults => 'No movies or series found.';

  @override
  String get discoveryLoadMore => 'Load more';

  @override
  String get discoveryMovie => 'Movie';

  @override
  String get discoverySeries => 'Series';

  @override
  String discoveryRating(String rating) {
    return 'Rating $rating';
  }

  @override
  String discoveryRuntimeMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String discoveryReleaseYear(int year) {
    return 'Released $year';
  }

  @override
  String get discoveryDetailsCloseTooltip => 'Close details';

  @override
  String get discoveryOverviewUnavailable => 'No description is available.';

  @override
  String get discoveryRequest => 'Request';

  @override
  String get discoveryRequestTitle => 'Request title';

  @override
  String discoveryRequestMessage(String title) {
    return 'Request “$title” from Seerr?';
  }

  @override
  String get discoveryRequestAllSeasons => 'All seasons';

  @override
  String get discoveryRequestSelectSeasons => 'Choose seasons';

  @override
  String discoveryRequestSeason(int number) {
    return 'Season $number';
  }

  @override
  String get discoveryRequestCancel => 'Cancel';

  @override
  String get discoveryRequestConfirm => 'Send request';

  @override
  String get discoveryRequestSuccess => 'Request sent to Seerr.';

  @override
  String get discoveryAvailabilityAvailable => 'Available';

  @override
  String get discoveryAvailabilityPending => 'Pending availability';

  @override
  String get discoveryAvailabilityProcessing => 'Processing';

  @override
  String get discoveryAvailabilityPartiallyAvailable => 'Partially available';

  @override
  String get discoveryAvailabilityDeleted => 'Removed from library';

  @override
  String get discoveryRequestPending => 'Request pending';

  @override
  String get discoveryRequestApproved => 'Request approved';

  @override
  String get discoveryRequestDeclined => 'Request declined';

  @override
  String get discoveryFailureMissingConfiguration =>
      'Discovery is not configured yet.';

  @override
  String get discoveryFailureInvalidEndpoint =>
      'The Seerr endpoint is invalid or redirected to another origin.';

  @override
  String get discoveryFailureUnauthorized =>
      'The supplied token or API key was rejected.';

  @override
  String get discoveryFailureForbidden => 'The server denied this action.';

  @override
  String get discoveryFailureConflict =>
      'This title already has a request or cannot be requested again.';

  @override
  String get discoveryFailureUnsupportedVersion =>
      'Seerr 3.1.0 or newer is required.';

  @override
  String get discoveryFailureTimeout =>
      'The discovery service did not respond in time.';

  @override
  String get discoveryFailureResponseTooLarge =>
      'The discovery response exceeded the safety limit.';

  @override
  String get discoveryFailureInvalidResponse =>
      'The discovery service returned an invalid response.';

  @override
  String get discoveryFailureNetwork =>
      'The discovery service could not be reached.';

  @override
  String get discoverySourceTmdb => 'TMDB';

  @override
  String get discoverySourceSeerr => 'Seerr';

  @override
  String get discoverySettingsTitle => 'Discovery';

  @override
  String get discoverySettingsDescription =>
      'Choose the Home source, startup destination and securely stored access credentials.';

  @override
  String get discoverySettingsSource => 'Home source';

  @override
  String get discoverySettingsStartupDestination => 'Start the app on';

  @override
  String get discoverySettingsStartupHome => 'Home';

  @override
  String get discoverySettingsStartupLive => 'Live TV';

  @override
  String get discoverySettingsTmdbToken => 'TMDB Read Access Token';

  @override
  String get discoverySettingsTmdbTokenHint =>
      'Bearer token from your TMDB API settings';

  @override
  String get discoverySettingsSeerrEndpoint => 'Seerr endpoint';

  @override
  String get discoverySettingsSeerrEndpointHint =>
      'https://seerr.example.com or a local address';

  @override
  String get discoverySettingsSeerrApiKey => 'Seerr administrator API key';

  @override
  String get discoverySettingsSeerrApiKeyHint =>
      'X-Api-Key from Seerr General Settings';

  @override
  String get discoverySettingsSecretStored =>
      'A secret is stored. Leave this field empty to keep it.';

  @override
  String get discoverySettingsSave => 'Save';

  @override
  String get discoverySettingsTestConnection => 'Test connection';

  @override
  String get discoverySettingsConnected => 'Connection successful';

  @override
  String discoverySettingsConnectedVersion(String version) {
    return 'Connected to Seerr $version';
  }

  @override
  String get discoverySettingsAdminKeyWarning =>
      'This API key grants administrator access to Seerr. LUNARR uses it only for discovery and new media requests.';

  @override
  String get discoverySettingsHttpWarning =>
      'This endpoint uses unencrypted HTTP. Continue only for a trusted local network.';

  @override
  String get discoverySettingsHttpConfirmTitle =>
      'Confirm unencrypted Seerr connection';

  @override
  String discoverySettingsHttpConfirmMessage(String host) {
    return 'The Seerr administrator API key will be sent without transport encryption to $host. Continue only if this host is on a trusted local network.';
  }

  @override
  String get discoverySettingsHttpConfirmCancel => 'Cancel';

  @override
  String get discoverySettingsHttpConfirmContinue => 'Continue';

  @override
  String get discoverySettingsSecretsInfo =>
      'Secrets are DPAPI-encrypted on Windows and are never written to logs or the app database.';

  @override
  String get discoverySettingsMinimumVersion =>
      'Seerr 3.1.0 or newer is required.';

  @override
  String get discoverySettingsSaved => 'Discovery settings saved.';

  @override
  String get discoverySettingsShowSecretTooltip => 'Show secret';

  @override
  String get discoverySettingsHideSecretTooltip => 'Hide secret';

  @override
  String get discoverySettingsClearSecretTooltip => 'Remove stored secret';

  @override
  String get discoveryFailureInsecureEndpointNotConfirmed =>
      'Confirm this unencrypted Seerr endpoint in Settings before connecting.';

  @override
  String discoveryEpisodeCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count episodes',
      one: '1 episode',
    );
    return '$_temp0';
  }

  @override
  String get discoveryCreditsTitle => 'Data source credits';

  @override
  String get discoveryTmdbLogoSemantics => 'The Movie Database logo';

  @override
  String get discoveryTmdbAttribution =>
      'This product uses the TMDB API but is not endorsed or certified by TMDB.';
}
