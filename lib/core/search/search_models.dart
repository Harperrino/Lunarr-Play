enum SearchResultTab { all, channels, categories }

enum SearchHitType { channel, category }

enum SearchIndexStatus { pending, building, ready, failed }

/// The complete input boundary for SQLite-backed global search.
///
/// The repository deliberately receives the current UI visibility state here
/// instead of reading the complete channel catalogue into Dart.
class SearchRequest {
  const SearchRequest({
    required this.query,
    required this.tab,
    required this.activePlaylistIds,
    this.hiddenGroupsByPlaylist = const <int, Set<String>>{},
    this.pinnedGroupsByPlaylist = const <int, Set<String>>{},
    this.limit = 12,
  });

  final String query;
  final SearchResultTab tab;
  final Set<int> activePlaylistIds;
  final Map<int, Set<String>> hiddenGroupsByPlaylist;
  final Map<int, Set<String>> pinnedGroupsByPlaylist;
  final int limit;
}

/// A compact search result. It contains only identifiers and display data;
/// playback URLs and the full [Channel] row are loaded after explicit
/// navigation.
class SearchHit {
  const SearchHit({
    required this.type,
    required this.playlistId,
    required this.playlistName,
    required this.mediaType,
    required this.title,
    required this.category,
    this.channelId,
    this.epgChannelId,
    this.isPinned = false,
    this.relevance = 0,
  });

  final SearchHitType type;
  final int playlistId;
  final String playlistName;
  final String mediaType;
  final String title;
  final String category;
  final int? channelId;
  final String? epgChannelId;
  final bool isPinned;
  final int relevance;
}

class SearchIndexPlaylistState {
  const SearchIndexPlaylistState({
    required this.playlistId,
    required this.playlistName,
    required this.status,
    required this.documentCount,
    required this.syncRevision,
  });

  final int playlistId;
  final String playlistName;
  final SearchIndexStatus status;
  final int documentCount;
  final int syncRevision;
}

class SearchIndexBuildState {
  const SearchIndexBuildState({required this.playlists});

  const SearchIndexBuildState.empty() : playlists = const [];

  final List<SearchIndexPlaylistState> playlists;

  int get total => playlists.length;
  int get readyCount =>
      playlists.where((item) => item.status == SearchIndexStatus.ready).length;
  int get pendingCount => playlists
      .where((item) => item.status == SearchIndexStatus.pending)
      .length;
  int get buildingCount => playlists
      .where((item) => item.status == SearchIndexStatus.building)
      .length;
  int get failedCount =>
      playlists.where((item) => item.status == SearchIndexStatus.failed).length;

  /// A failed playlist is incomplete, but it is no longer actively building.
  /// Keeping that distinction lets the UI offer retry without showing a
  /// misleading progress spinner.
  bool get isBuilding => pendingCount > 0 || buildingCount > 0;
  bool get isComplete => total == 0 || readyCount == total;
}
