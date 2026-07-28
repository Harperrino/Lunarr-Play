import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// Public application title.
  ///
  /// In en, this message translates to:
  /// **'Lunarr Player'**
  String get appTitle;

  /// No description provided for @globalSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search channels, movies, and series…'**
  String get globalSearchHint;

  /// No description provided for @globalSearchClearTooltip.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get globalSearchClearTooltip;

  /// No description provided for @globalSearchSemanticsLabel.
  ///
  /// In en, this message translates to:
  /// **'Global search'**
  String get globalSearchSemanticsLabel;

  /// No description provided for @globalSearchUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Search is unavailable'**
  String get globalSearchUnavailable;

  /// No description provided for @globalSearchIndexBuildingProgress.
  ///
  /// In en, this message translates to:
  /// **'Building search index… {ready}/{total}'**
  String globalSearchIndexBuildingProgress(int ready, int total);

  /// No description provided for @globalSearchLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading search…'**
  String get globalSearchLoading;

  /// No description provided for @globalSearchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get globalSearchNoResults;

  /// No description provided for @globalSearchOpenHint.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get globalSearchOpenHint;

  /// No description provided for @globalSearchFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get globalSearchFilterAll;

  /// No description provided for @globalSearchFilterChannels.
  ///
  /// In en, this message translates to:
  /// **'Channels'**
  String get globalSearchFilterChannels;

  /// No description provided for @globalSearchFilterCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get globalSearchFilterCategories;

  /// No description provided for @globalSearchIndexProgressSemantics.
  ///
  /// In en, this message translates to:
  /// **'Search index: {ready} of {total} playlists'**
  String globalSearchIndexProgressSemantics(int ready, int total);

  /// No description provided for @globalSearchIndexRetrySemantics.
  ///
  /// In en, this message translates to:
  /// **'Search index: {count} incomplete playlists. Retry'**
  String globalSearchIndexRetrySemantics(int count);

  /// No description provided for @globalSearchIndexIncompletePlaylists.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 playlist is not fully indexed} other{{count} playlists are not fully indexed}}'**
  String globalSearchIndexIncompletePlaylists(int count);

  /// No description provided for @globalSearchRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get globalSearchRetry;

  /// No description provided for @globalSearchEpgLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading EPG…'**
  String get globalSearchEpgLoading;

  /// No description provided for @globalSearchEpgUnavailable.
  ///
  /// In en, this message translates to:
  /// **'EPG unavailable'**
  String get globalSearchEpgUnavailable;

  /// No description provided for @globalSearchEpgNow.
  ///
  /// In en, this message translates to:
  /// **'Now: {title}'**
  String globalSearchEpgNow(String title);

  /// No description provided for @globalSearchEpgNone.
  ///
  /// In en, this message translates to:
  /// **'No EPG'**
  String get globalSearchEpgNone;

  /// No description provided for @globalSearchResultSemantics.
  ///
  /// In en, this message translates to:
  /// **'{title} · {metadata}'**
  String globalSearchResultSemantics(String title, String metadata);

  /// No description provided for @playlistMenuTitle.
  ///
  /// In en, this message translates to:
  /// **'Playlists'**
  String get playlistMenuTitle;

  /// No description provided for @playlistMenuAdd.
  ///
  /// In en, this message translates to:
  /// **'Add playlist'**
  String get playlistMenuAdd;

  /// No description provided for @playlistMenuAllActiveSelection.
  ///
  /// In en, this message translates to:
  /// **'All active playlists'**
  String get playlistMenuAllActiveSelection;

  /// No description provided for @playlistMenuChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose playlist'**
  String get playlistMenuChoose;

  /// No description provided for @playlistMenuStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get playlistMenuStatusActive;

  /// No description provided for @playlistMenuStatusInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get playlistMenuStatusInactive;

  /// No description provided for @playlistMenuAllLabel.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get playlistMenuAllLabel;

  /// No description provided for @playlistMenuActivePlaylistsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Active playlists'**
  String get playlistMenuActivePlaylistsSubtitle;

  /// No description provided for @playlistMenuSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing…'**
  String get playlistMenuSyncing;

  /// No description provided for @playlistMenuSyncFailed.
  ///
  /// In en, this message translates to:
  /// **'Sync failed'**
  String get playlistMenuSyncFailed;

  /// No description provided for @playlistMenuSyncTooltip.
  ///
  /// In en, this message translates to:
  /// **'Sync playlist'**
  String get playlistMenuSyncTooltip;

  /// No description provided for @playlistMenuManageTooltip.
  ///
  /// In en, this message translates to:
  /// **'Manage playlist'**
  String get playlistMenuManageTooltip;

  /// No description provided for @playlistDialogCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not create playlist: {error}'**
  String playlistDialogCreateFailed(String error);

  /// No description provided for @playlistDialogAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add playlist'**
  String get playlistDialogAddTitle;

  /// No description provided for @playlistDialogCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get playlistDialogCancel;

  /// No description provided for @playlistDialogAddAndSync.
  ///
  /// In en, this message translates to:
  /// **'Add and sync'**
  String get playlistDialogAddAndSync;

  /// No description provided for @playlistDialogEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit {type} playlist'**
  String playlistDialogEditTitle(String type);

  /// No description provided for @playlistDialogNameField.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get playlistDialogNameField;

  /// No description provided for @playlistDialogHostField.
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get playlistDialogHostField;

  /// No description provided for @playlistDialogUrlOrFileField.
  ///
  /// In en, this message translates to:
  /// **'URL or file path'**
  String get playlistDialogUrlOrFileField;

  /// No description provided for @playlistDialogUsernameField.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get playlistDialogUsernameField;

  /// No description provided for @playlistDialogPasswordField.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get playlistDialogPasswordField;

  /// No description provided for @playlistDialogAutomaticUrlTitle.
  ///
  /// In en, this message translates to:
  /// **'Detected automatically'**
  String get playlistDialogAutomaticUrlTitle;

  /// No description provided for @playlistDialogNoAutomaticUrl.
  ///
  /// In en, this message translates to:
  /// **'No URL was detected from the source.'**
  String get playlistDialogNoAutomaticUrl;

  /// No description provided for @playlistDialogEpgOverrideField.
  ///
  /// In en, this message translates to:
  /// **'EPG override (optional)'**
  String get playlistDialogEpgOverrideField;

  /// No description provided for @playlistDialogEpgOverrideHint.
  ///
  /// In en, this message translates to:
  /// **'Leave empty to use the automatic URL'**
  String get playlistDialogEpgOverrideHint;

  /// No description provided for @playlistDialogEffectiveUrl.
  ///
  /// In en, this message translates to:
  /// **'Effective: {url}'**
  String playlistDialogEffectiveUrl(String url);

  /// No description provided for @playlistDialogSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get playlistDialogSaving;

  /// No description provided for @playlistDialogSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get playlistDialogSave;

  /// No description provided for @playlistHubLoadError.
  ///
  /// In en, this message translates to:
  /// **'Failed to load playlists: {error}'**
  String playlistHubLoadError(String error);

  /// No description provided for @playlistHubTitle.
  ///
  /// In en, this message translates to:
  /// **'Playlists'**
  String get playlistHubTitle;

  /// No description provided for @playlistHubSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Activate, sync, and manage each playlist separately.'**
  String get playlistHubSubtitle;

  /// No description provided for @playlistHubAdd.
  ///
  /// In en, this message translates to:
  /// **'Add playlist'**
  String get playlistHubAdd;

  /// No description provided for @playlistHubCategoryVisibilityTitle.
  ///
  /// In en, this message translates to:
  /// **'Category visibility'**
  String get playlistHubCategoryVisibilityTitle;

  /// No description provided for @playlistHubCategoryVisibilitySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pin what matters, hide what you do not need, and keep the same order everywhere.'**
  String get playlistHubCategoryVisibilitySubtitle;

  /// No description provided for @playlistHubSyncToLoadCategories.
  ///
  /// In en, this message translates to:
  /// **'Sync the playlist to load categories.'**
  String get playlistHubSyncToLoadCategories;

  /// No description provided for @playlistHubVisibleCategoriesSection.
  ///
  /// In en, this message translates to:
  /// **'Visible categories'**
  String get playlistHubVisibleCategoriesSection;

  /// No description provided for @playlistHubHiddenCategoriesSection.
  ///
  /// In en, this message translates to:
  /// **'Hidden categories'**
  String get playlistHubHiddenCategoriesSection;

  /// No description provided for @playlistHubDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete playlist?'**
  String get playlistHubDeleteTitle;

  /// No description provided for @playlistHubDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'The playlist “{name}” and its local data will be removed.'**
  String playlistHubDeleteBody(String name);

  /// No description provided for @playlistHubDeleteCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get playlistHubDeleteCancel;

  /// No description provided for @playlistHubDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get playlistHubDeleteConfirm;

  /// No description provided for @playlistHubDeleteSuccess.
  ///
  /// In en, this message translates to:
  /// **'Playlist “{name}” deleted.'**
  String playlistHubDeleteSuccess(String name);

  /// No description provided for @playlistHubDeleteFailure.
  ///
  /// In en, this message translates to:
  /// **'Delete failed: {error}'**
  String playlistHubDeleteFailure(String error);

  /// No description provided for @playlistHubContentFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get playlistHubContentFilterAll;

  /// No description provided for @playlistHubContentFilterLive.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get playlistHubContentFilterLive;

  /// No description provided for @playlistHubContentFilterVod.
  ///
  /// In en, this message translates to:
  /// **'VOD'**
  String get playlistHubContentFilterVod;

  /// No description provided for @playlistHubContentFilterSeries.
  ///
  /// In en, this message translates to:
  /// **'Series'**
  String get playlistHubContentFilterSeries;

  /// No description provided for @playlistHubEmptyCategoriesAll.
  ///
  /// In en, this message translates to:
  /// **'No categories found in this playlist.'**
  String get playlistHubEmptyCategoriesAll;

  /// No description provided for @playlistHubEmptyCategoriesLive.
  ///
  /// In en, this message translates to:
  /// **'No live categories found in this playlist.'**
  String get playlistHubEmptyCategoriesLive;

  /// No description provided for @playlistHubEmptyCategoriesVod.
  ///
  /// In en, this message translates to:
  /// **'No VOD categories found in this playlist.'**
  String get playlistHubEmptyCategoriesVod;

  /// No description provided for @playlistHubEmptyCategoriesSeries.
  ///
  /// In en, this message translates to:
  /// **'No series categories found in this playlist.'**
  String get playlistHubEmptyCategoriesSeries;

  /// No description provided for @playlistHubStatusInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get playlistHubStatusInactive;

  /// No description provided for @playlistHubStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get playlistHubStatusActive;

  /// No description provided for @playlistHubStatusSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing…'**
  String get playlistHubStatusSyncing;

  /// No description provided for @playlistHubStatusEpgSyncing.
  ///
  /// In en, this message translates to:
  /// **'EPG syncing…'**
  String get playlistHubStatusEpgSyncing;

  /// No description provided for @playlistHubStatusEpgError.
  ///
  /// In en, this message translates to:
  /// **'EPG error'**
  String get playlistHubStatusEpgError;

  /// No description provided for @playlistHubStatusEpgReady.
  ///
  /// In en, this message translates to:
  /// **'EPG ready'**
  String get playlistHubStatusEpgReady;

  /// No description provided for @playlistHubStatusEpgInterval.
  ///
  /// In en, this message translates to:
  /// **'EPG {interval}'**
  String playlistHubStatusEpgInterval(String interval);

  /// No description provided for @playlistHubSyncTooltip.
  ///
  /// In en, this message translates to:
  /// **'Sync playlist'**
  String get playlistHubSyncTooltip;

  /// No description provided for @playlistHubMoreActionsTooltip.
  ///
  /// In en, this message translates to:
  /// **'More playlist actions'**
  String get playlistHubMoreActionsTooltip;

  /// No description provided for @playlistHubSyncAction.
  ///
  /// In en, this message translates to:
  /// **'Sync playlist'**
  String get playlistHubSyncAction;

  /// No description provided for @playlistHubNoEpgUrl.
  ///
  /// In en, this message translates to:
  /// **'No EPG URL configured'**
  String get playlistHubNoEpgUrl;

  /// No description provided for @playlistHubRetryEpgAction.
  ///
  /// In en, this message translates to:
  /// **'Retry EPG'**
  String get playlistHubRetryEpgAction;

  /// No description provided for @playlistHubSyncEpgAction.
  ///
  /// In en, this message translates to:
  /// **'Sync EPG'**
  String get playlistHubSyncEpgAction;

  /// No description provided for @playlistHubManageAction.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get playlistHubManageAction;

  /// No description provided for @playlistHubEditAction.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get playlistHubEditAction;

  /// No description provided for @playlistHubDeleteAction.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get playlistHubDeleteAction;

  /// No description provided for @playlistHubAutomaticEpgTitle.
  ///
  /// In en, this message translates to:
  /// **'Automatically sync EPG'**
  String get playlistHubAutomaticEpgTitle;

  /// No description provided for @playlistHubEpgIntervalManual.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get playlistHubEpgIntervalManual;

  /// No description provided for @playlistHubEpgIntervalHours6.
  ///
  /// In en, this message translates to:
  /// **'Every 6 hours'**
  String get playlistHubEpgIntervalHours6;

  /// No description provided for @playlistHubEpgIntervalHours12.
  ///
  /// In en, this message translates to:
  /// **'Every 12 hours'**
  String get playlistHubEpgIntervalHours12;

  /// No description provided for @playlistHubEpgIntervalHours24.
  ///
  /// In en, this message translates to:
  /// **'Every 24 hours'**
  String get playlistHubEpgIntervalHours24;

  /// No description provided for @playlistHubCategoryVisibleDescription.
  ///
  /// In en, this message translates to:
  /// **'Visible in all category sidebars'**
  String get playlistHubCategoryVisibleDescription;

  /// No description provided for @playlistHubCategoryHiddenDescription.
  ///
  /// In en, this message translates to:
  /// **'Hidden from sidebar lists'**
  String get playlistHubCategoryHiddenDescription;

  /// No description provided for @playlistHubUnpinCategoryTooltip.
  ///
  /// In en, this message translates to:
  /// **'Unpin category'**
  String get playlistHubUnpinCategoryTooltip;

  /// No description provided for @playlistHubPinCategoryTooltip.
  ///
  /// In en, this message translates to:
  /// **'Pin category'**
  String get playlistHubPinCategoryTooltip;

  /// No description provided for @playlistHubSummaryVisible.
  ///
  /// In en, this message translates to:
  /// **'Visible'**
  String get playlistHubSummaryVisible;

  /// No description provided for @playlistHubSummaryPinned.
  ///
  /// In en, this message translates to:
  /// **'Pinned'**
  String get playlistHubSummaryPinned;

  /// No description provided for @playlistHubSummaryHidden.
  ///
  /// In en, this message translates to:
  /// **'Hidden'**
  String get playlistHubSummaryHidden;

  /// No description provided for @playlistHubSummaryHiddenPinned.
  ///
  /// In en, this message translates to:
  /// **'Hidden pinned'**
  String get playlistHubSummaryHiddenPinned;

  /// No description provided for @playlistHubHideAllCategories.
  ///
  /// In en, this message translates to:
  /// **'Hide all'**
  String get playlistHubHideAllCategories;

  /// No description provided for @playlistHubHideLiveCategories.
  ///
  /// In en, this message translates to:
  /// **'Hide live categories'**
  String get playlistHubHideLiveCategories;

  /// No description provided for @playlistHubHideVodCategories.
  ///
  /// In en, this message translates to:
  /// **'Hide VOD categories'**
  String get playlistHubHideVodCategories;

  /// No description provided for @playlistHubHideSeriesCategories.
  ///
  /// In en, this message translates to:
  /// **'Hide series categories'**
  String get playlistHubHideSeriesCategories;

  /// No description provided for @playlistHubShowAllCategories.
  ///
  /// In en, this message translates to:
  /// **'Show all'**
  String get playlistHubShowAllCategories;

  /// No description provided for @playlistHubShowLiveCategories.
  ///
  /// In en, this message translates to:
  /// **'Show live categories'**
  String get playlistHubShowLiveCategories;

  /// No description provided for @playlistHubShowVodCategories.
  ///
  /// In en, this message translates to:
  /// **'Show VOD categories'**
  String get playlistHubShowVodCategories;

  /// No description provided for @playlistHubShowSeriesCategories.
  ///
  /// In en, this message translates to:
  /// **'Show series categories'**
  String get playlistHubShowSeriesCategories;

  /// No description provided for @playlistHubEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No playlists yet'**
  String get playlistHubEmptyTitle;

  /// No description provided for @playlistHubEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add your first source and manage it here.'**
  String get playlistHubEmptySubtitle;

  /// No description provided for @diagnosticsConsoleTitle.
  ///
  /// In en, this message translates to:
  /// **'SYSTEM REAL-TIME DIAGNOSTICS'**
  String get diagnosticsConsoleTitle;

  /// No description provided for @diagnosticsConsoleClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get diagnosticsConsoleClear;

  /// No description provided for @diagnosticsConsoleKeyboardHelp.
  ///
  /// In en, this message translates to:
  /// **'Press [Space] to play or pause, [F] for fullscreen, [+/-] for volume, and [Arrow keys] to change channels.'**
  String get diagnosticsConsoleKeyboardHelp;

  /// No description provided for @channelFavoriteRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove from favorites'**
  String get channelFavoriteRemove;

  /// No description provided for @channelFavoriteAdd.
  ///
  /// In en, this message translates to:
  /// **'Add to favorites'**
  String get channelFavoriteAdd;

  /// No description provided for @audioTrackChooseTooltip.
  ///
  /// In en, this message translates to:
  /// **'Choose audio track'**
  String get audioTrackChooseTooltip;

  /// No description provided for @audioTrackNoneDetectedTooltip.
  ///
  /// In en, this message translates to:
  /// **'No audio tracks detected'**
  String get audioTrackNoneDetectedTooltip;

  /// No description provided for @audioTrackAutomatic.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get audioTrackAutomatic;

  /// No description provided for @playerEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Select a channel to play'**
  String get playerEmptyTitle;

  /// No description provided for @playerEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Select a channel from the list or use the arrow keys.'**
  String get playerEmptySubtitle;

  /// No description provided for @playbackAudioRawNone.
  ///
  /// In en, this message translates to:
  /// **'No raw audio tracks detected'**
  String get playbackAudioRawNone;

  /// No description provided for @playbackAudioNoneSelectable.
  ///
  /// In en, this message translates to:
  /// **'Audio tracks detected, but none are currently selectable'**
  String get playbackAudioNoneSelectable;

  /// No description provided for @playbackAudioTrackCounts.
  ///
  /// In en, this message translates to:
  /// **'{rawCount} raw / {selectableCount} selectable'**
  String playbackAudioTrackCounts(int rawCount, int selectableCount);

  /// No description provided for @playbackAudioNotExposed.
  ///
  /// In en, this message translates to:
  /// **'Audio track not exposed by stream or demuxer'**
  String get playbackAudioNotExposed;

  /// No description provided for @playbackAudioNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get playbackAudioNone;

  /// No description provided for @playbackInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Playback information'**
  String get playbackInfoTitle;

  /// No description provided for @playbackInfoCloseTooltip.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get playbackInfoCloseTooltip;

  /// No description provided for @playbackInfoTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get playbackInfoTitleLabel;

  /// No description provided for @playbackInfoGroupLabel.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get playbackInfoGroupLabel;

  /// No description provided for @playbackInfoTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get playbackInfoTypeLabel;

  /// No description provided for @playbackInfoResolutionLabel.
  ///
  /// In en, this message translates to:
  /// **'Resolution'**
  String get playbackInfoResolutionLabel;

  /// No description provided for @playbackInfoVideoFormatLabel.
  ///
  /// In en, this message translates to:
  /// **'Video format'**
  String get playbackInfoVideoFormatLabel;

  /// No description provided for @playbackInfoAudioTrackLabel.
  ///
  /// In en, this message translates to:
  /// **'Audio track'**
  String get playbackInfoAudioTrackLabel;

  /// No description provided for @playbackInfoAudioTrackStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Audio track status'**
  String get playbackInfoAudioTrackStatusLabel;

  /// No description provided for @playbackInfoAudioDecodedLabel.
  ///
  /// In en, this message translates to:
  /// **'Audio decoded'**
  String get playbackInfoAudioDecodedLabel;

  /// No description provided for @playbackInfoAudioFormatLabel.
  ///
  /// In en, this message translates to:
  /// **'Audio format'**
  String get playbackInfoAudioFormatLabel;

  /// No description provided for @playbackInfoAudioChannelsLabel.
  ///
  /// In en, this message translates to:
  /// **'Audio channels'**
  String get playbackInfoAudioChannelsLabel;

  /// No description provided for @playbackInfoAudioHintLabel.
  ///
  /// In en, this message translates to:
  /// **'Audio note'**
  String get playbackInfoAudioHintLabel;

  /// No description provided for @playbackInfoSampleRateLabel.
  ///
  /// In en, this message translates to:
  /// **'Sample rate'**
  String get playbackInfoSampleRateLabel;

  /// No description provided for @playbackInfoAudioBitrateLabel.
  ///
  /// In en, this message translates to:
  /// **'Audio bitrate'**
  String get playbackInfoAudioBitrateLabel;

  /// No description provided for @playbackInfoContainerLabel.
  ///
  /// In en, this message translates to:
  /// **'Container'**
  String get playbackInfoContainerLabel;

  /// No description provided for @playbackInfoPositionLabel.
  ///
  /// In en, this message translates to:
  /// **'Position'**
  String get playbackInfoPositionLabel;

  /// No description provided for @playbackInfoDurationLabel.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get playbackInfoDurationLabel;

  /// No description provided for @playbackInfoDemuxerBufferLabel.
  ///
  /// In en, this message translates to:
  /// **'Buffer (demuxer)'**
  String get playbackInfoDemuxerBufferLabel;

  /// No description provided for @playbackInfoBufferedUntilLabel.
  ///
  /// In en, this message translates to:
  /// **'Buffered until'**
  String get playbackInfoBufferedUntilLabel;

  /// No description provided for @playbackInfoStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get playbackInfoStatusLabel;

  /// No description provided for @playbackInfoYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get playbackInfoYes;

  /// No description provided for @playbackInfoNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get playbackInfoNo;

  /// No description provided for @playbackInfoBuffering.
  ///
  /// In en, this message translates to:
  /// **'Buffering…'**
  String get playbackInfoBuffering;

  /// No description provided for @playbackInfoPlaying.
  ///
  /// In en, this message translates to:
  /// **'Playing'**
  String get playbackInfoPlaying;

  /// No description provided for @playbackInfoPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get playbackInfoPaused;

  /// No description provided for @playbackInfoTypeVod.
  ///
  /// In en, this message translates to:
  /// **'Movie (VOD)'**
  String get playbackInfoTypeVod;

  /// No description provided for @playbackInfoTypeSeries.
  ///
  /// In en, this message translates to:
  /// **'Series / episode'**
  String get playbackInfoTypeSeries;

  /// No description provided for @playbackInfoTypeLive.
  ///
  /// In en, this message translates to:
  /// **'Live TV'**
  String get playbackInfoTypeLive;

  /// No description provided for @episodeCardSemantics.
  ///
  /// In en, this message translates to:
  /// **'Episode: {title}'**
  String episodeCardSemantics(String title);

  /// No description provided for @movieCardSemantics.
  ///
  /// In en, this message translates to:
  /// **'Movie: {title}'**
  String movieCardSemantics(String title);

  /// No description provided for @seriesCardSemantics.
  ///
  /// In en, this message translates to:
  /// **'Series: {title}'**
  String seriesCardSemantics(String title);

  /// No description provided for @epgNowMarkerSemantics.
  ///
  /// In en, this message translates to:
  /// **'Now, current time in the programme'**
  String get epgNowMarkerSemantics;

  /// No description provided for @epgNowMarkerLabel.
  ///
  /// In en, this message translates to:
  /// **'NOW'**
  String get epgNowMarkerLabel;

  /// No description provided for @epgToolbarTitle.
  ///
  /// In en, this message translates to:
  /// **'TV PROGRAMME'**
  String get epgToolbarTitle;

  /// No description provided for @epgToolbarNow.
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get epgToolbarNow;

  /// No description provided for @epgToolbarJumpToNowTooltip.
  ///
  /// In en, this message translates to:
  /// **'Go to the current time'**
  String get epgToolbarJumpToNowTooltip;

  /// No description provided for @epgToolbarBackTwoHoursTooltip.
  ///
  /// In en, this message translates to:
  /// **'Go back two hours'**
  String get epgToolbarBackTwoHoursTooltip;

  /// No description provided for @epgToolbarForwardTwoHoursTooltip.
  ///
  /// In en, this message translates to:
  /// **'Go forward two hours'**
  String get epgToolbarForwardTwoHoursTooltip;

  /// No description provided for @epgToolbarBackOneDayTooltip.
  ///
  /// In en, this message translates to:
  /// **'Go back one day'**
  String get epgToolbarBackOneDayTooltip;

  /// No description provided for @epgToolbarForwardOneDayTooltip.
  ///
  /// In en, this message translates to:
  /// **'Go forward one day'**
  String get epgToolbarForwardOneDayTooltip;

  /// No description provided for @epgToolbarZoomOutTooltip.
  ///
  /// In en, this message translates to:
  /// **'Zoom out the timeline'**
  String get epgToolbarZoomOutTooltip;

  /// No description provided for @epgToolbarZoomInTooltip.
  ///
  /// In en, this message translates to:
  /// **'Zoom in the timeline'**
  String get epgToolbarZoomInTooltip;

  /// No description provided for @epgToolbarResetZoomTooltip.
  ///
  /// In en, this message translates to:
  /// **'Reset the timeline to 100 percent'**
  String get epgToolbarResetZoomTooltip;

  /// No description provided for @playlistFormTitle.
  ///
  /// In en, this message translates to:
  /// **'ADD PLAYLIST'**
  String get playlistFormTitle;

  /// No description provided for @playlistFormDescription.
  ///
  /// In en, this message translates to:
  /// **'Create a new source and keep the flow focused on setup, sync, and playback.'**
  String get playlistFormDescription;

  /// No description provided for @playlistFormNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get playlistFormNameLabel;

  /// No description provided for @playlistFormNameHint.
  ///
  /// In en, this message translates to:
  /// **'My IPTV list'**
  String get playlistFormNameHint;

  /// No description provided for @playlistFormUrlOrFileLabel.
  ///
  /// In en, this message translates to:
  /// **'URL or file path'**
  String get playlistFormUrlOrFileLabel;

  /// No description provided for @playlistFormHostLabel.
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get playlistFormHostLabel;

  /// No description provided for @playlistFormUsernameLabel.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get playlistFormUsernameLabel;

  /// No description provided for @playlistFormPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get playlistFormPasswordLabel;

  /// No description provided for @playlistFormEpgOverrideLabel.
  ///
  /// In en, this message translates to:
  /// **'EPG override (optional)'**
  String get playlistFormEpgOverrideLabel;

  /// No description provided for @playlistFormEpgOverrideHint.
  ///
  /// In en, this message translates to:
  /// **'Leave empty to use the automatic URL'**
  String get playlistFormEpgOverrideHint;

  /// No description provided for @playlistFormWorking.
  ///
  /// In en, this message translates to:
  /// **'Working…'**
  String get playlistFormWorking;

  /// No description provided for @playlistFormAddAndSync.
  ///
  /// In en, this message translates to:
  /// **'Add and sync'**
  String get playlistFormAddAndSync;

  /// No description provided for @appearanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearanceTitle;

  /// No description provided for @appearanceDescription.
  ///
  /// In en, this message translates to:
  /// **'Adjust the accent and neutral surfaces independently.'**
  String get appearanceDescription;

  /// No description provided for @appearanceRestoreDefaults.
  ///
  /// In en, this message translates to:
  /// **'Restore defaults'**
  String get appearanceRestoreDefaults;

  /// No description provided for @appearanceAccentColor.
  ///
  /// In en, this message translates to:
  /// **'Accent color'**
  String get appearanceAccentColor;

  /// No description provided for @appearanceNeutralSurfaceTone.
  ///
  /// In en, this message translates to:
  /// **'Neutral gray / surface tone'**
  String get appearanceNeutralSurfaceTone;

  /// No description provided for @appearanceDegreesSemantics.
  ///
  /// In en, this message translates to:
  /// **'{value} degrees'**
  String appearanceDegreesSemantics(int value);

  /// No description provided for @appearancePercentSemantics.
  ///
  /// In en, this message translates to:
  /// **'{value} percent'**
  String appearancePercentSemantics(int value);

  /// No description provided for @appearancePreviewLiveTv.
  ///
  /// In en, this message translates to:
  /// **'Live TV'**
  String get appearancePreviewLiveTv;

  /// No description provided for @appearancePreviewLibrary.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get appearancePreviewLibrary;

  /// No description provided for @appearancePreviewSelect.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get appearancePreviewSelect;

  /// No description provided for @debugModeTitle.
  ///
  /// In en, this message translates to:
  /// **'DEBUG MODE'**
  String get debugModeTitle;

  /// No description provided for @debugModeDescription.
  ///
  /// In en, this message translates to:
  /// **'Shows the Diagnostics / Logs tab and keeps collecting logs even when hidden.'**
  String get debugModeDescription;

  /// No description provided for @debugModeDiagnosticsOn.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics on'**
  String get debugModeDiagnosticsOn;

  /// No description provided for @debugModeHidden.
  ///
  /// In en, this message translates to:
  /// **'Hidden'**
  String get debugModeHidden;

  /// No description provided for @debugModeEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get debugModeEnabled;

  /// No description provided for @debugModeDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get debugModeDisabled;

  /// No description provided for @settingsSectionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Sections'**
  String get settingsSectionsTitle;

  /// No description provided for @settingsSectionGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get settingsSectionGeneral;

  /// No description provided for @settingsSectionPlaylistSetup.
  ///
  /// In en, this message translates to:
  /// **'Playlist setup'**
  String get settingsSectionPlaylistSetup;

  /// No description provided for @settingsSectionSavedPlaylists.
  ///
  /// In en, this message translates to:
  /// **'Saved playlists'**
  String get settingsSectionSavedPlaylists;

  /// No description provided for @favoriteSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save favorite.'**
  String get favoriteSaveFailed;

  /// No description provided for @favoritesLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load favorites'**
  String get favoritesLoadFailed;

  /// No description provided for @favoritesNoPlaylistTitle.
  ///
  /// In en, this message translates to:
  /// **'No playlist selected'**
  String get favoritesNoPlaylistTitle;

  /// No description provided for @favoritesNoPlaylistSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Select a playlist to see your favorites.'**
  String get favoritesNoPlaylistSubtitle;

  /// No description provided for @favoritesEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No live favorites yet'**
  String get favoritesEmptyTitle;

  /// No description provided for @favoritesEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Favorites from your active playlist will appear here.'**
  String get favoritesEmptySubtitle;

  /// No description provided for @favoriteChannelSemantics.
  ///
  /// In en, this message translates to:
  /// **'Favorite: {title}'**
  String favoriteChannelSemantics(String title);

  /// No description provided for @favoriteIconSemantics.
  ///
  /// In en, this message translates to:
  /// **'Favorite'**
  String get favoriteIconSemantics;

  /// No description provided for @favoritePlayLiveSemantics.
  ///
  /// In en, this message translates to:
  /// **'Play live'**
  String get favoritePlayLiveSemantics;

  /// No description provided for @watchLaterRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove from Watch Later'**
  String get watchLaterRemove;

  /// No description provided for @watchLaterSave.
  ///
  /// In en, this message translates to:
  /// **'Save for later'**
  String get watchLaterSave;

  /// No description provided for @watchLaterLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load Watch Later'**
  String get watchLaterLoadFailed;

  /// No description provided for @watchLaterNoPlaylistSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Select an active playlist first.'**
  String get watchLaterNoPlaylistSubtitle;

  /// No description provided for @watchLaterEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing saved for later yet'**
  String get watchLaterEmptyTitle;

  /// No description provided for @watchLaterEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Bookmark movies or series to keep them here.'**
  String get watchLaterEmptySubtitle;

  /// No description provided for @catalogNoPlaylistSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Select a playlist in the Playlists tab or Settings.'**
  String get catalogNoPlaylistSubtitle;

  /// No description provided for @catalogResetFilters.
  ///
  /// In en, this message translates to:
  /// **'Reset filters'**
  String get catalogResetFilters;

  /// No description provided for @catalogSyncPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Sync playlist'**
  String get catalogSyncPlaylist;

  /// No description provided for @catalogSyncingPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Syncing playlist…'**
  String get catalogSyncingPlaylist;

  /// No description provided for @catalogGenresTitle.
  ///
  /// In en, this message translates to:
  /// **'Genres'**
  String get catalogGenresTitle;

  /// No description provided for @catalogSyncAction.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get catalogSyncAction;

  /// No description provided for @vodLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load movies'**
  String get vodLoadFailed;

  /// No description provided for @vodNoSearchResults.
  ///
  /// In en, this message translates to:
  /// **'No movies match your search'**
  String get vodNoSearchResults;

  /// No description provided for @vodNoVisibleMovies.
  ///
  /// In en, this message translates to:
  /// **'No movies visible'**
  String get vodNoVisibleMovies;

  /// No description provided for @vodNoMoviesFound.
  ///
  /// In en, this message translates to:
  /// **'No movies found'**
  String get vodNoMoviesFound;

  /// No description provided for @vodClearSearchSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Clear the search field to show all movies again.'**
  String get vodClearSearchSubtitle;

  /// No description provided for @vodHiddenByFiltersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your VOD catalogue is loaded, but filters or hidden categories are hiding the visible list.'**
  String get vodHiddenByFiltersSubtitle;

  /// No description provided for @vodSyncSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sync your Xtream playlist to load VOD movies.'**
  String get vodSyncSubtitle;

  /// No description provided for @vodToolbarTitle.
  ///
  /// In en, this message translates to:
  /// **'VOD MOVIES'**
  String get vodToolbarTitle;

  /// No description provided for @seriesLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load series'**
  String get seriesLoadFailed;

  /// No description provided for @seriesNoSearchResults.
  ///
  /// In en, this message translates to:
  /// **'No series match your search'**
  String get seriesNoSearchResults;

  /// No description provided for @seriesNoVisibleSeries.
  ///
  /// In en, this message translates to:
  /// **'No series visible'**
  String get seriesNoVisibleSeries;

  /// No description provided for @seriesNoSeriesFound.
  ///
  /// In en, this message translates to:
  /// **'No series found'**
  String get seriesNoSeriesFound;

  /// No description provided for @seriesClearSearchSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Clear the search field to show all series again.'**
  String get seriesClearSearchSubtitle;

  /// No description provided for @seriesHiddenByFiltersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your series catalogue is loaded, but filters or hidden categories are hiding the visible list.'**
  String get seriesHiddenByFiltersSubtitle;

  /// No description provided for @seriesSyncSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sync your Xtream playlist to load series.'**
  String get seriesSyncSubtitle;

  /// No description provided for @seriesToolbarTitle.
  ///
  /// In en, this message translates to:
  /// **'SERIES'**
  String get seriesToolbarTitle;

  /// No description provided for @epgNoSearchResults.
  ///
  /// In en, this message translates to:
  /// **'No channels match your search'**
  String get epgNoSearchResults;

  /// No description provided for @epgClearSearchSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Clear the search field to show all {count} channels again.'**
  String epgClearSearchSubtitle(int count);

  /// No description provided for @epgNoChannelsTitle.
  ///
  /// In en, this message translates to:
  /// **'No channels loaded'**
  String get epgNoChannelsTitle;

  /// No description provided for @epgNoChannelsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Select a playlist and sync channels on the Live tab or in Settings.'**
  String get epgNoChannelsSubtitle;

  /// No description provided for @epgNoDataTitle.
  ///
  /// In en, this message translates to:
  /// **'No EPG data for this time window'**
  String get epgNoDataTitle;

  /// No description provided for @epgUpdateGuideSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Update the TV programme guide for your active playlist.'**
  String get epgUpdateGuideSubtitle;

  /// No description provided for @epgConfigureUrlSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Configure an EPG URL in Settings or sync an M3U playlist with a url-tvg header.'**
  String get epgConfigureUrlSubtitle;

  /// No description provided for @epgUpdateAction.
  ///
  /// In en, this message translates to:
  /// **'Update EPG'**
  String get epgUpdateAction;

  /// No description provided for @playbackSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'PLAYBACK'**
  String get playbackSettingsTitle;

  /// No description provided for @playbackSettingsDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose how much content is buffered before live playback starts. Higher values delay startup but reduce stuttering on unstable streams.'**
  String get playbackSettingsDescription;

  /// No description provided for @playbackSettingsLiveBufferLabel.
  ///
  /// In en, this message translates to:
  /// **'Live startup buffer'**
  String get playbackSettingsLiveBufferLabel;

  /// No description provided for @playbackSettingsVodBufferDescription.
  ///
  /// In en, this message translates to:
  /// **'VOD pre-buffering loads media before playback for smoother seeking. Higher values require more time and bandwidth.'**
  String get playbackSettingsVodBufferDescription;

  /// No description provided for @playbackSettingsVodBufferLabel.
  ///
  /// In en, this message translates to:
  /// **'VOD pre-buffer'**
  String get playbackSettingsVodBufferLabel;

  /// No description provided for @playbackSettingsForceStereoTitle.
  ///
  /// In en, this message translates to:
  /// **'Force stereo'**
  String get playbackSettingsForceStereoTitle;

  /// No description provided for @playbackSettingsForceStereoDescription.
  ///
  /// In en, this message translates to:
  /// **'Helps with external sound cards, mixing consoles, or channels with multichannel audio.'**
  String get playbackSettingsForceStereoDescription;

  /// No description provided for @playbackSettingsPreferredLanguageTitle.
  ///
  /// In en, this message translates to:
  /// **'Preferred audio language'**
  String get playbackSettingsPreferredLanguageTitle;

  /// No description provided for @playbackSettingsPreferredLanguageDescription.
  ///
  /// In en, this message translates to:
  /// **'When multiple audio tracks are available, this language is preferred.'**
  String get playbackSettingsPreferredLanguageDescription;

  /// No description provided for @playbackSettingsLanguageAutomatic.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get playbackSettingsLanguageAutomatic;

  /// No description provided for @playbackSettingsLanguageGerman.
  ///
  /// In en, this message translates to:
  /// **'German'**
  String get playbackSettingsLanguageGerman;

  /// No description provided for @playbackSettingsBufferOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get playbackSettingsBufferOff;

  /// No description provided for @playbackSettingsBufferSeconds.
  ///
  /// In en, this message translates to:
  /// **'{seconds, plural, =1{1 second} other{{seconds} seconds}}'**
  String playbackSettingsBufferSeconds(int seconds);

  /// No description provided for @playbackSettingsBufferMaximum.
  ///
  /// In en, this message translates to:
  /// **'{seconds} seconds (maximum)'**
  String playbackSettingsBufferMaximum(int seconds);

  /// No description provided for @seriesPlayEpisode.
  ///
  /// In en, this message translates to:
  /// **'Play — {title}'**
  String seriesPlayEpisode(String title);

  /// No description provided for @seriesEpisodesTab.
  ///
  /// In en, this message translates to:
  /// **'Episodes'**
  String get seriesEpisodesTab;

  /// No description provided for @commonBackTooltip.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBackTooltip;

  /// No description provided for @seriesContinueWatching.
  ///
  /// In en, this message translates to:
  /// **'Continue watching'**
  String get seriesContinueWatching;

  /// No description provided for @seriesContinueAction.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get seriesContinueAction;

  /// No description provided for @seriesNoEpisodes.
  ///
  /// In en, this message translates to:
  /// **'No episodes found.'**
  String get seriesNoEpisodes;

  /// No description provided for @channelRefreshFailedRetained.
  ///
  /// In en, this message translates to:
  /// **'Channels could not be refreshed. The last loaded channels remain visible.'**
  String get channelRefreshFailedRetained;

  /// No description provided for @channelLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load channels'**
  String get channelLoadFailed;

  /// No description provided for @channelNoPlaylistSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add and sync a playlist to see channels here.'**
  String get channelNoPlaylistSubtitle;

  /// No description provided for @channelNoSearchResults.
  ///
  /// In en, this message translates to:
  /// **'No channels match your search'**
  String get channelNoSearchResults;

  /// No description provided for @channelNoChannelsFound.
  ///
  /// In en, this message translates to:
  /// **'No channels found'**
  String get channelNoChannelsFound;

  /// No description provided for @channelClearSearchSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Clear the search field to show all channels again.'**
  String get channelClearSearchSubtitle;

  /// No description provided for @channelSyncOrFilterSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sync your playlist or try a different category filter.'**
  String get channelSyncOrFilterSubtitle;

  /// No description provided for @channelSyncFailed.
  ///
  /// In en, this message translates to:
  /// **'Sync failed: {error}'**
  String channelSyncFailed(String error);

  /// No description provided for @channelEpgUpdated.
  ///
  /// In en, this message translates to:
  /// **'EPG updated successfully.'**
  String get channelEpgUpdated;

  /// No description provided for @channelEpgSyncFailed.
  ///
  /// In en, this message translates to:
  /// **'EPG sync failed: {error}'**
  String channelEpgSyncFailed(String error);

  /// No description provided for @channelPlaylistCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No playlists} =1{1 playlist} other{{count} playlists}}'**
  String channelPlaylistCount(int count);

  /// No description provided for @channelAllActivePlaylists.
  ///
  /// In en, this message translates to:
  /// **'All active playlists'**
  String get channelAllActivePlaylists;

  /// No description provided for @channelLiveTitle.
  ///
  /// In en, this message translates to:
  /// **'LIVE CHANNELS'**
  String get channelLiveTitle;

  /// No description provided for @channelUncategorized.
  ///
  /// In en, this message translates to:
  /// **'Uncategorized'**
  String get channelUncategorized;

  /// No description provided for @channelLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading channels…'**
  String get channelLoading;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @channelSortTooltip.
  ///
  /// In en, this message translates to:
  /// **'Sort: {mode}'**
  String channelSortTooltip(String mode);

  /// No description provided for @channelSortProvider.
  ///
  /// In en, this message translates to:
  /// **'Provider order'**
  String get channelSortProvider;

  /// No description provided for @channelSortAlphabetical.
  ///
  /// In en, this message translates to:
  /// **'Alphabetical'**
  String get channelSortAlphabetical;

  /// No description provided for @channelSortNumber.
  ///
  /// In en, this message translates to:
  /// **'Channel number'**
  String get channelSortNumber;

  /// No description provided for @channelEpgNow.
  ///
  /// In en, this message translates to:
  /// **'Now: {title}'**
  String channelEpgNow(String title);

  /// No description provided for @channelEpgLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading EPG…'**
  String get channelEpgLoading;

  /// No description provided for @channelNoEpg.
  ///
  /// In en, this message translates to:
  /// **'No EPG'**
  String get channelNoEpg;

  /// No description provided for @channelEpgNotUpdated.
  ///
  /// In en, this message translates to:
  /// **'The TV programme guide (EPG) has not been updated yet.'**
  String get channelEpgNotUpdated;

  /// No description provided for @channelEpgUpdating.
  ///
  /// In en, this message translates to:
  /// **'Updating…'**
  String get channelEpgUpdating;

  /// No description provided for @channelEpgUpdateNow.
  ///
  /// In en, this message translates to:
  /// **'Update EPG now'**
  String get channelEpgUpdateNow;

  /// No description provided for @commonDismissTooltip.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get commonDismissTooltip;

  /// No description provided for @commonSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing…'**
  String get commonSyncing;

  /// No description provided for @commonSync.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get commonSync;

  /// No description provided for @mediaLibraryMoviesTab.
  ///
  /// In en, this message translates to:
  /// **'Movies'**
  String get mediaLibraryMoviesTab;

  /// No description provided for @mediaLibrarySeriesTab.
  ///
  /// In en, this message translates to:
  /// **'Series'**
  String get mediaLibrarySeriesTab;

  /// No description provided for @mediaLibraryWatchLaterTab.
  ///
  /// In en, this message translates to:
  /// **'Watch Later'**
  String get mediaLibraryWatchLaterTab;

  /// No description provided for @epgAgendaNext.
  ///
  /// In en, this message translates to:
  /// **'Next: {title}'**
  String epgAgendaNext(String title);

  /// No description provided for @epgAgendaNow.
  ///
  /// In en, this message translates to:
  /// **'NOW: {title}'**
  String epgAgendaNow(String title);

  /// No description provided for @epgAgendaUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No EPG available'**
  String get epgAgendaUnavailable;

  /// No description provided for @epgAgendaNoCurrentProgram.
  ///
  /// In en, this message translates to:
  /// **'No programme currently airing'**
  String get epgAgendaNoCurrentProgram;

  /// No description provided for @epgAgendaChannelSemantics.
  ///
  /// In en, this message translates to:
  /// **'Channel: {name}'**
  String epgAgendaChannelSemantics(String name);

  /// No description provided for @epgAgendaLiveSemantics.
  ///
  /// In en, this message translates to:
  /// **'LIVE, now playing: {title}'**
  String epgAgendaLiveSemantics(String title);

  /// No description provided for @epgAgendaStartChannel.
  ///
  /// In en, this message translates to:
  /// **'Play channel'**
  String get epgAgendaStartChannel;

  /// No description provided for @epgLiveNowSemantics.
  ///
  /// In en, this message translates to:
  /// **'LIVE, now playing'**
  String get epgLiveNowSemantics;

  /// No description provided for @commonLiveLabel.
  ///
  /// In en, this message translates to:
  /// **'LIVE'**
  String get commonLiveLabel;

  /// No description provided for @epgProgramLiveSemantics.
  ///
  /// In en, this message translates to:
  /// **'Live now: {title}'**
  String epgProgramLiveSemantics(String title);

  /// No description provided for @epgProgramSemantics.
  ///
  /// In en, this message translates to:
  /// **'Programme: {title}'**
  String epgProgramSemantics(String title);

  /// No description provided for @epgProgramDurationMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes, plural, =1{1 min} other{{minutes} min}}'**
  String epgProgramDurationMinutes(int minutes);

  /// No description provided for @epgGridChannelHeader.
  ///
  /// In en, this message translates to:
  /// **'CHANNEL'**
  String get epgGridChannelHeader;

  /// No description provided for @epgGridChannelSemantics.
  ///
  /// In en, this message translates to:
  /// **'Channel: {name}. {status}'**
  String epgGridChannelSemantics(String name, String status);

  /// No description provided for @epgGridNoProgramme.
  ///
  /// In en, this message translates to:
  /// **'No programme'**
  String get epgGridNoProgramme;

  /// No description provided for @epgGridNoEpg.
  ///
  /// In en, this message translates to:
  /// **'No EPG'**
  String get epgGridNoEpg;

  /// No description provided for @epgTimelineResizeSemantics.
  ///
  /// In en, this message translates to:
  /// **'Adjust time column width'**
  String get epgTimelineResizeSemantics;

  /// No description provided for @epgTimelineResizeHint.
  ///
  /// In en, this message translates to:
  /// **'Use the arrow keys to adjust it step by step'**
  String get epgTimelineResizeHint;

  /// No description provided for @diagnosticsSettingsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load streaming diagnostics settings: {error}'**
  String diagnosticsSettingsLoadFailed(String error);

  /// No description provided for @diagnosticsStreamingTitle.
  ///
  /// In en, this message translates to:
  /// **'PLAYER & STREAMING'**
  String get diagnosticsStreamingTitle;

  /// No description provided for @diagnosticsStreamingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Advanced diagnostics'**
  String get diagnosticsStreamingSubtitle;

  /// No description provided for @diagnosticsFallbackOn.
  ///
  /// In en, this message translates to:
  /// **'Fallback on'**
  String get diagnosticsFallbackOn;

  /// No description provided for @diagnosticsFallbackOff.
  ///
  /// In en, this message translates to:
  /// **'Fallback off'**
  String get diagnosticsFallbackOff;

  /// No description provided for @diagnosticsAutoFallbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Use fallback automatically'**
  String get diagnosticsAutoFallbackTitle;

  /// No description provided for @diagnosticsAutoFallbackSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Automatically try the live fallback matrix before showing an error.'**
  String get diagnosticsAutoFallbackSubtitle;

  /// No description provided for @diagnosticsShowOnErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Show diagnostics on error'**
  String get diagnosticsShowOnErrorTitle;

  /// No description provided for @diagnosticsShowOnErrorSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Writes a short diagnostic entry to the UI logs when live playback fails to start.'**
  String get diagnosticsShowOnErrorSubtitle;

  /// No description provided for @diagnosticsCopyLastFailure.
  ///
  /// In en, this message translates to:
  /// **'Copy last failure'**
  String get diagnosticsCopyLastFailure;

  /// No description provided for @diagnosticsLastFailureCopied.
  ///
  /// In en, this message translates to:
  /// **'Last streaming failure copied.'**
  String get diagnosticsLastFailureCopied;

  /// No description provided for @diagnosticsCopyPlayerLog.
  ///
  /// In en, this message translates to:
  /// **'Copy player log'**
  String get diagnosticsCopyPlayerLog;

  /// No description provided for @diagnosticsPlayerLogCopied.
  ///
  /// In en, this message translates to:
  /// **'Player log copied.'**
  String get diagnosticsPlayerLogCopied;

  /// No description provided for @diagnosticsTestStream.
  ///
  /// In en, this message translates to:
  /// **'Test stream'**
  String get diagnosticsTestStream;

  /// No description provided for @diagnosticsStreamCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Stream check failed.'**
  String get diagnosticsStreamCheckFailed;

  /// No description provided for @diagnosticsLastFailureTitle.
  ///
  /// In en, this message translates to:
  /// **'Last streaming failure'**
  String get diagnosticsLastFailureTitle;

  /// No description provided for @playerPreviousChannelTooltip.
  ///
  /// In en, this message translates to:
  /// **'Previous channel'**
  String get playerPreviousChannelTooltip;

  /// No description provided for @playerPlayTooltip.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get playerPlayTooltip;

  /// No description provided for @playerPauseTooltip.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get playerPauseTooltip;

  /// No description provided for @playerStopTooltip.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get playerStopTooltip;

  /// No description provided for @playerNextChannelTooltip.
  ///
  /// In en, this message translates to:
  /// **'Next channel'**
  String get playerNextChannelTooltip;

  /// No description provided for @playerPlaybackInfoTooltip.
  ///
  /// In en, this message translates to:
  /// **'Playback information'**
  String get playerPlaybackInfoTooltip;

  /// No description provided for @playerFullscreenTooltip.
  ///
  /// In en, this message translates to:
  /// **'Fullscreen'**
  String get playerFullscreenTooltip;

  /// No description provided for @playerNowPlaying.
  ///
  /// In en, this message translates to:
  /// **'Now playing: {title}'**
  String playerNowPlaying(String title);

  /// No description provided for @playerPositionSemantics.
  ///
  /// In en, this message translates to:
  /// **'Position {position}'**
  String playerPositionSemantics(String position);

  /// No description provided for @playerBufferedAhead.
  ///
  /// In en, this message translates to:
  /// **'{duration} ahead'**
  String playerBufferedAhead(String duration);

  /// No description provided for @playerBuffering.
  ///
  /// In en, this message translates to:
  /// **'Buffering…'**
  String get playerBuffering;

  /// No description provided for @playerLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get playerLoading;

  /// No description provided for @playerStartupBufferProgress.
  ///
  /// In en, this message translates to:
  /// **'Startup buffer {current} / {target}'**
  String playerStartupBufferProgress(String current, String target);

  /// No description provided for @playerStartupBufferBuilding.
  ///
  /// In en, this message translates to:
  /// **'Building startup buffer…'**
  String get playerStartupBufferBuilding;

  /// No description provided for @playerBuffered.
  ///
  /// In en, this message translates to:
  /// **'{duration} buffered'**
  String playerBuffered(String duration);

  /// No description provided for @playerStabilizingLive.
  ///
  /// In en, this message translates to:
  /// **'Stabilizing live connection…'**
  String get playerStabilizingLive;

  /// No description provided for @playerLiveInstantStart.
  ///
  /// In en, this message translates to:
  /// **'Live — instant start'**
  String get playerLiveInstantStart;

  /// No description provided for @playerLiveRollingBuffer.
  ///
  /// In en, this message translates to:
  /// **'Live — rolling buffer active'**
  String get playerLiveRollingBuffer;

  /// No description provided for @playerStartsAtBuffer.
  ///
  /// In en, this message translates to:
  /// **'Starts at {target}'**
  String playerStartsAtBuffer(String target);

  /// No description provided for @playerLiveCacheActive.
  ///
  /// In en, this message translates to:
  /// **'Live cache active'**
  String get playerLiveCacheActive;

  /// No description provided for @playerTargetBuffer.
  ///
  /// In en, this message translates to:
  /// **'Target buffer {target}'**
  String playerTargetBuffer(String target);

  /// No description provided for @playerMaximumBuffer.
  ///
  /// In en, this message translates to:
  /// **'Max {duration}'**
  String playerMaximumBuffer(String duration);

  /// No description provided for @playerVolumeSemantics.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get playerVolumeSemantics;

  /// No description provided for @playerUnmuteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get playerUnmuteTooltip;

  /// No description provided for @playerMuteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get playerMuteTooltip;

  /// No description provided for @playerVolumePercentSemantics.
  ///
  /// In en, this message translates to:
  /// **'Volume {percent} percent'**
  String playerVolumePercentSemantics(int percent);

  /// No description provided for @playerNoChannelSelected.
  ///
  /// In en, this message translates to:
  /// **'No channel selected'**
  String get playerNoChannelSelected;

  /// No description provided for @playerStatusIdle.
  ///
  /// In en, this message translates to:
  /// **'IDLE'**
  String get playerStatusIdle;

  /// No description provided for @playerStatusStabilizing.
  ///
  /// In en, this message translates to:
  /// **'STABILIZING'**
  String get playerStatusStabilizing;

  /// No description provided for @playerStatusWarmingUp.
  ///
  /// In en, this message translates to:
  /// **'WARMING UP'**
  String get playerStatusWarmingUp;

  /// No description provided for @playerStatusBuffering.
  ///
  /// In en, this message translates to:
  /// **'BUFFERING'**
  String get playerStatusBuffering;

  /// No description provided for @playerStatusLive.
  ///
  /// In en, this message translates to:
  /// **'LIVE'**
  String get playerStatusLive;

  /// No description provided for @playerStatusPaused.
  ///
  /// In en, this message translates to:
  /// **'PAUSED'**
  String get playerStatusPaused;

  /// No description provided for @playerExitFullscreenHint.
  ///
  /// In en, this message translates to:
  /// **'Press F or Esc to exit fullscreen'**
  String get playerExitFullscreenHint;

  /// No description provided for @playerLivePlaybackTitle.
  ///
  /// In en, this message translates to:
  /// **'LIVE PLAYBACK'**
  String get playerLivePlaybackTitle;

  /// No description provided for @playerStatusError.
  ///
  /// In en, this message translates to:
  /// **'ERROR'**
  String get playerStatusError;

  /// No description provided for @playerStatusReady.
  ///
  /// In en, this message translates to:
  /// **'READY'**
  String get playerStatusReady;

  /// No description provided for @playerStatusConnecting.
  ///
  /// In en, this message translates to:
  /// **'CONNECTING'**
  String get playerStatusConnecting;

  /// No description provided for @playerStatusOnAir.
  ///
  /// In en, this message translates to:
  /// **'ON AIR'**
  String get playerStatusOnAir;

  /// No description provided for @playerSelectChannelTitle.
  ///
  /// In en, this message translates to:
  /// **'Select a channel'**
  String get playerSelectChannelTitle;

  /// No description provided for @playerSelectChannelFullscreenSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Exit fullscreen (F / Esc) and select a channel from the list.'**
  String get playerSelectChannelFullscreenSubtitle;

  /// No description provided for @playerPlaybackFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Playback failed'**
  String get playerPlaybackFailedTitle;

  /// No description provided for @playerVideoInitializationFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not initialize video output.'**
  String get playerVideoInitializationFailed;

  /// No description provided for @playbackPrepEpisodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Prepare episode'**
  String get playbackPrepEpisodeTitle;

  /// No description provided for @playbackPrepMovieTitle.
  ///
  /// In en, this message translates to:
  /// **'Prepare movie'**
  String get playbackPrepMovieTitle;

  /// No description provided for @playbackPrepEpisodeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pre-buffered start for a smoother episode handoff.'**
  String get playbackPrepEpisodeSubtitle;

  /// No description provided for @playbackPrepMovieSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pre-buffered start for smoother seeking and faster resume.'**
  String get playbackPrepMovieSubtitle;

  /// No description provided for @playbackPrepBufferingProgress.
  ///
  /// In en, this message translates to:
  /// **'Buffering… {percent}%'**
  String playbackPrepBufferingProgress(int percent);

  /// No description provided for @playbackPrepOpeningStream.
  ///
  /// In en, this message translates to:
  /// **'Opening stream…'**
  String get playbackPrepOpeningStream;

  /// No description provided for @playbackPrepCompleted.
  ///
  /// In en, this message translates to:
  /// **'Preparation complete'**
  String get playbackPrepCompleted;

  /// No description provided for @playbackPrepReady.
  ///
  /// In en, this message translates to:
  /// **'Ready to play'**
  String get playbackPrepReady;

  /// No description provided for @playbackPrepDetectedMedia.
  ///
  /// In en, this message translates to:
  /// **'Detected: {resolution}{container}'**
  String playbackPrepDetectedMedia(String resolution, String container);

  /// No description provided for @playbackPrepEpisodeExplanation.
  ///
  /// In en, this message translates to:
  /// **'Buffer the episode before playback for smoother seeking and resume.'**
  String get playbackPrepEpisodeExplanation;

  /// No description provided for @playbackPrepMovieExplanation.
  ///
  /// In en, this message translates to:
  /// **'Buffer before playback for smoother forward and backward seeking.'**
  String get playbackPrepMovieExplanation;

  /// No description provided for @playbackPrepLoadingAction.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get playbackPrepLoadingAction;

  /// No description provided for @playbackPrepPrepareAction.
  ///
  /// In en, this message translates to:
  /// **'Prepare'**
  String get playbackPrepPrepareAction;

  /// No description provided for @playbackPrepStartAction.
  ///
  /// In en, this message translates to:
  /// **'Start playback'**
  String get playbackPrepStartAction;

  /// No description provided for @playbackPrepStartImmediatelyAction.
  ///
  /// In en, this message translates to:
  /// **'Start immediately'**
  String get playbackPrepStartImmediatelyAction;

  /// No description provided for @playbackPrepStartPosition.
  ///
  /// In en, this message translates to:
  /// **'Start at {position}'**
  String playbackPrepStartPosition(String position);

  /// No description provided for @playbackPrepEpisodeDetail.
  ///
  /// In en, this message translates to:
  /// **'Buffer the episode before playback for smoother seeking within the episode.'**
  String get playbackPrepEpisodeDetail;

  /// No description provided for @playbackPrepMovieDetail.
  ///
  /// In en, this message translates to:
  /// **'Buffer before playback for smoother forward and backward seeking.'**
  String get playbackPrepMovieDetail;

  /// No description provided for @playbackPrepToggleTitle.
  ///
  /// In en, this message translates to:
  /// **'Pre-buffer'**
  String get playbackPrepToggleTitle;

  /// No description provided for @playbackPrepToggleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Loads approximately {seconds} seconds before playback (Settings → Playback)'**
  String playbackPrepToggleSubtitle(int seconds);

  /// No description provided for @windowMinimizeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Minimize'**
  String get windowMinimizeTooltip;

  /// No description provided for @windowMaximizeRestoreTooltip.
  ///
  /// In en, this message translates to:
  /// **'Maximize / Restore'**
  String get windowMaximizeRestoreTooltip;

  /// No description provided for @windowCloseTooltip.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get windowCloseTooltip;

  /// No description provided for @paneCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get paneCategories;

  /// No description provided for @paneChannels.
  ///
  /// In en, this message translates to:
  /// **'Channel list'**
  String get paneChannels;

  /// No description provided for @paneCollapseAction.
  ///
  /// In en, this message translates to:
  /// **'Collapse {pane}'**
  String paneCollapseAction(String pane);

  /// No description provided for @paneExpandAction.
  ///
  /// In en, this message translates to:
  /// **'Expand {pane}'**
  String paneExpandAction(String pane);

  /// No description provided for @categoryPaneResizeLabel.
  ///
  /// In en, this message translates to:
  /// **'Resize category pane'**
  String get categoryPaneResizeLabel;

  /// No description provided for @categoryPaneResizeHint.
  ///
  /// In en, this message translates to:
  /// **'Drag to resize; double-click to reset'**
  String get categoryPaneResizeHint;

  /// No description provided for @stepperDecreaseValue.
  ///
  /// In en, this message translates to:
  /// **'Decrease value'**
  String get stepperDecreaseValue;

  /// No description provided for @stepperIncreaseValue.
  ///
  /// In en, this message translates to:
  /// **'Increase value'**
  String get stepperIncreaseValue;

  /// No description provided for @databaseFatalSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Database connection interrupted. Restart the application.'**
  String get databaseFatalSemanticLabel;

  /// No description provided for @databaseFatalMessage.
  ///
  /// In en, this message translates to:
  /// **'Database connection interrupted — please restart the application.'**
  String get databaseFatalMessage;

  /// No description provided for @comingSoonTitle.
  ///
  /// In en, this message translates to:
  /// **'Feature — Coming Soon'**
  String get comingSoonTitle;

  /// No description provided for @comingSoonDescription.
  ///
  /// In en, this message translates to:
  /// **'This section is planned for a future milestone.'**
  String get comingSoonDescription;

  /// No description provided for @playbackSettingsLanguageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get playbackSettingsLanguageEnglish;

  /// No description provided for @playbackSettingsLanguageFrench.
  ///
  /// In en, this message translates to:
  /// **'Français'**
  String get playbackSettingsLanguageFrench;

  /// No description provided for @playbackSettingsLanguageSpanish.
  ///
  /// In en, this message translates to:
  /// **'Español'**
  String get playbackSettingsLanguageSpanish;

  /// No description provided for @playbackSettingsLanguageItalian.
  ///
  /// In en, this message translates to:
  /// **'Italiano'**
  String get playbackSettingsLanguageItalian;

  /// No description provided for @playbackSettingsLanguagePortuguese.
  ///
  /// In en, this message translates to:
  /// **'Português'**
  String get playbackSettingsLanguagePortuguese;

  /// No description provided for @playbackSettingsLanguageTurkish.
  ///
  /// In en, this message translates to:
  /// **'Türkçe'**
  String get playbackSettingsLanguageTurkish;

  /// No description provided for @playbackSettingsLanguageRussian.
  ///
  /// In en, this message translates to:
  /// **'Русский'**
  String get playbackSettingsLanguageRussian;

  /// No description provided for @shellTabLiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Live TV'**
  String get shellTabLiveTitle;

  /// No description provided for @shellTabLiveSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Watch live channels — select a playlist and tap to play.'**
  String get shellTabLiveSubtitle;

  /// No description provided for @shellTabMediaLibraryTitle.
  ///
  /// In en, this message translates to:
  /// **'Media Library'**
  String get shellTabMediaLibraryTitle;

  /// No description provided for @shellTabMediaLibrarySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Movies, series, and Watch Later in one shared media library.'**
  String get shellTabMediaLibrarySubtitle;

  /// No description provided for @shellTabFavoritesTitle.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get shellTabFavoritesTitle;

  /// No description provided for @shellTabFavoritesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Quick access to your favorite live channels.'**
  String get shellTabFavoritesSubtitle;

  /// No description provided for @shellTabPlaylistsTitle.
  ///
  /// In en, this message translates to:
  /// **'Playlists'**
  String get shellTabPlaylistsTitle;

  /// No description provided for @shellTabPlaylistsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Switch playlists and manage which categories are visible.'**
  String get shellTabPlaylistsSubtitle;

  /// No description provided for @shellTabEpgTitle.
  ///
  /// In en, this message translates to:
  /// **'EPG Guide'**
  String get shellTabEpgTitle;

  /// No description provided for @shellTabEpgSubtitle.
  ///
  /// In en, this message translates to:
  /// **'TV program guide for the active playlist — select a show to watch live.'**
  String get shellTabEpgSubtitle;

  /// No description provided for @shellTabVodTitle.
  ///
  /// In en, this message translates to:
  /// **'VOD Movies'**
  String get shellTabVodTitle;

  /// No description provided for @shellTabVodSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Browse movies from your active playlist — select one to play on the Live tab.'**
  String get shellTabVodSubtitle;

  /// No description provided for @shellTabSeriesTitle.
  ///
  /// In en, this message translates to:
  /// **'Series'**
  String get shellTabSeriesTitle;

  /// No description provided for @shellTabSeriesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Browse series — open a show for episodes and resume where you left off.'**
  String get shellTabSeriesSubtitle;

  /// No description provided for @shellTabDiagnosticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics / Logs'**
  String get shellTabDiagnosticsTitle;

  /// No description provided for @shellTabDiagnosticsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Debug-only log console and runtime diagnostics.'**
  String get shellTabDiagnosticsSubtitle;

  /// No description provided for @shellTabSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get shellTabSettingsTitle;

  /// No description provided for @shellTabSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add, sync, and manage M3U and Xtream playlists.'**
  String get shellTabSettingsSubtitle;

  /// No description provided for @shellFallbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Neural Control Center'**
  String get shellFallbackTitle;

  /// No description provided for @shellFallbackSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Material 3 media workspace (Drift & Riverpod)'**
  String get shellFallbackSubtitle;

  /// No description provided for @shellSidebarLabel.
  ///
  /// In en, this message translates to:
  /// **'Sidebar'**
  String get shellSidebarLabel;

  /// No description provided for @liveStartupBufferOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get liveStartupBufferOff;

  /// No description provided for @liveStartupBufferSeconds.
  ///
  /// In en, this message translates to:
  /// **'{seconds} seconds'**
  String liveStartupBufferSeconds(int seconds);

  /// No description provided for @liveStartupBufferSecondsMaximum.
  ///
  /// In en, this message translates to:
  /// **'{seconds} seconds (maximum)'**
  String liveStartupBufferSecondsMaximum(int seconds);

  /// No description provided for @playerPanelError.
  ///
  /// In en, this message translates to:
  /// **'Player error: {error}'**
  String playerPanelError(String error);

  /// No description provided for @playerAudioDetectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Detecting audio'**
  String get playerAudioDetectionTitle;

  /// No description provided for @playerAudioDetectionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Detecting audio track…'**
  String get playerAudioDetectionSubtitle;

  /// No description provided for @playerAudioSynchronizationTitle.
  ///
  /// In en, this message translates to:
  /// **'Synchronizing audio'**
  String get playerAudioSynchronizationTitle;

  /// No description provided for @playerAudioSynchronizationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Stabilizing audio track…'**
  String get playerAudioSynchronizationSubtitle;

  /// No description provided for @playerInstantStartActive.
  ///
  /// In en, this message translates to:
  /// **'Instant start active'**
  String get playerInstantStartActive;

  /// No description provided for @playerStartsAtBufferTarget.
  ///
  /// In en, this message translates to:
  /// **'Starts at {target} buffer'**
  String playerStartsAtBufferTarget(String target);

  /// No description provided for @playerBuildingLiveBuffer.
  ///
  /// In en, this message translates to:
  /// **'Building live buffer'**
  String get playerBuildingLiveBuffer;

  /// No description provided for @playerPreparingStream.
  ///
  /// In en, this message translates to:
  /// **'Preparing stream'**
  String get playerPreparingStream;

  /// No description provided for @playerDetectingAudio.
  ///
  /// In en, this message translates to:
  /// **'Detecting audio…'**
  String get playerDetectingAudio;

  /// No description provided for @playerEstablishingConnection.
  ///
  /// In en, this message translates to:
  /// **'Establishing connection…'**
  String get playerEstablishingConnection;

  /// No description provided for @epgGridNowProgram.
  ///
  /// In en, this message translates to:
  /// **'Now: {title}'**
  String epgGridNowProgram(String title);

  /// No description provided for @playbackPrepVideoSurfaceTimeout.
  ///
  /// In en, this message translates to:
  /// **'Video output was not ready in time. Please start playback again.'**
  String get playbackPrepVideoSurfaceTimeout;

  /// No description provided for @globalSearchTargetLive.
  ///
  /// In en, this message translates to:
  /// **'Live TV'**
  String get globalSearchTargetLive;

  /// No description provided for @globalSearchTargetMovies.
  ///
  /// In en, this message translates to:
  /// **'Movies'**
  String get globalSearchTargetMovies;

  /// No description provided for @globalSearchTargetSeries.
  ///
  /// In en, this message translates to:
  /// **'Series'**
  String get globalSearchTargetSeries;

  /// No description provided for @globalSearchCategoryVisibleLabel.
  ///
  /// In en, this message translates to:
  /// **'{category} · {target} · {playlist}'**
  String globalSearchCategoryVisibleLabel(
    String category,
    String target,
    String playlist,
  );

  /// No description provided for @globalSearchCategoryMetadata.
  ///
  /// In en, this message translates to:
  /// **'{target} · {playlist}'**
  String globalSearchCategoryMetadata(String target, String playlist);

  /// No description provided for @playbackAudioMultichannelHint.
  ///
  /// In en, this message translates to:
  /// **'Multichannel audio decoded. If no sound is audible, try Force stereo.'**
  String get playbackAudioMultichannelHint;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
