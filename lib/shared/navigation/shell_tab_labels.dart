import 'package:m3uxtream_player/l10n/generated/app_localizations.dart';
import 'package:m3uxtream_player/shared/navigation/shell_tabs.dart';

String shellTabTitle(ShellTabSpec tab, AppLocalizations l10n) =>
    switch (tab.kind) {
      ShellTabKind.live => l10n.shellTabLiveTitle,
      ShellTabKind.mediaLibrary => l10n.shellTabMediaLibraryTitle,
      ShellTabKind.jellyfin => l10n.shellTabJellyfinTitle,
      ShellTabKind.favorites => l10n.shellTabFavoritesTitle,
      ShellTabKind.playlists => l10n.shellTabPlaylistsTitle,
      ShellTabKind.epg => l10n.shellTabEpgTitle,
      ShellTabKind.vod => l10n.shellTabVodTitle,
      ShellTabKind.series => l10n.shellTabSeriesTitle,
      ShellTabKind.diagnostics => l10n.shellTabDiagnosticsTitle,
      ShellTabKind.settings => l10n.shellTabSettingsTitle,
    };

String shellTabSubtitle(ShellTabSpec tab, AppLocalizations l10n) =>
    switch (tab.kind) {
      ShellTabKind.live => l10n.shellTabLiveSubtitle,
      ShellTabKind.mediaLibrary => l10n.shellTabMediaLibrarySubtitle,
      ShellTabKind.jellyfin => l10n.shellTabJellyfinSubtitle,
      ShellTabKind.favorites => l10n.shellTabFavoritesSubtitle,
      ShellTabKind.playlists => l10n.shellTabPlaylistsSubtitle,
      ShellTabKind.epg => l10n.shellTabEpgSubtitle,
      ShellTabKind.vod => l10n.shellTabVodSubtitle,
      ShellTabKind.series => l10n.shellTabSeriesSubtitle,
      ShellTabKind.diagnostics => l10n.shellTabDiagnosticsSubtitle,
      ShellTabKind.settings => l10n.shellTabSettingsSubtitle,
    };
