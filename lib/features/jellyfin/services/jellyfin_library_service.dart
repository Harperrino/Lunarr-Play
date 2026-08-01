import 'package:m3uxtream_player/core/logger/app_logger.dart';
import 'package:m3uxtream_player/features/jellyfin/api/jellyfin_api_client.dart';
import 'package:m3uxtream_player/features/jellyfin/api/jellyfin_api_exception.dart';
import 'package:m3uxtream_player/features/jellyfin/auth/jellyfin_connection.dart';
import 'package:m3uxtream_player/features/jellyfin/models/jellyfin_item.dart';
import 'package:m3uxtream_player/features/jellyfin/models/jellyfin_library.dart';

/// Aggregated data for the Jellyfin home screen.
class JellyfinHomeData {
  const JellyfinHomeData({
    this.resumeItems = const [],
    this.nextUpItems = const [],
    this.latestItems = const [],
    this.libraries = const [],
  });

  final List<JellyfinItem> resumeItems;
  final List<JellyfinItem> nextUpItems;
  final List<JellyfinItem> latestItems;
  final List<JellyfinLibrary> libraries;

  bool get isEmpty =>
      resumeItems.isEmpty &&
      nextUpItems.isEmpty &&
      latestItems.isEmpty &&
      libraries.isEmpty;
}

/// Orchestrates library browsing against the Jellyfin API.
class JellyfinLibraryService {
  const JellyfinLibraryService({required this._apiClient});

  final JellyfinApiClient _apiClient;

  /// Loads the home screen sections.
  ///
  /// Individual sections degrade to empty lists on failure so one broken
  /// endpoint never destroys the whole Jellyfin tab; only the library list
  /// failure is fatal.
  Future<JellyfinHomeData> fetchHomeData(JellyfinConnection connection) async {
    final libraries = await _apiClient.fetchUserViews(connection);
    final results = await Future.wait([
      _degraded(() => _apiClient.fetchResumeItems(connection)),
      _degraded(() => _apiClient.fetchNextUp(connection)),
      _degraded(() => _apiClient.fetchLatestItems(connection)),
    ]);
    return JellyfinHomeData(
      resumeItems: results[0],
      nextUpItems: results[1],
      latestItems: results[2],
      libraries: libraries,
    );
  }

  Future<List<JellyfinItem>> fetchLibraryItems(
    JellyfinConnection connection,
    JellyfinLibrary library,
  ) {
    final itemTypes = switch (library.collectionType) {
      'movies' => const ['Movie'],
      'tvshows' => const ['Series'],
      _ => const ['Movie', 'Series'],
    };
    return _apiClient.fetchLibraryItems(
      connection,
      libraryId: library.id,
      itemTypes: itemTypes,
    );
  }

  Future<JellyfinItem> fetchItemDetail(
    JellyfinConnection connection,
    String itemId,
  ) {
    return _apiClient.fetchItemDetail(connection, itemId: itemId);
  }

  Future<List<JellyfinItem>> fetchSeriesEpisodes(
    JellyfinConnection connection,
    String seriesId,
  ) {
    return _apiClient.fetchSeriesEpisodes(connection, seriesId: seriesId);
  }

  Future<List<JellyfinItem>> _degraded(
    Future<List<JellyfinItem>> Function() fetch,
  ) async {
    try {
      return await fetch();
    } on JellyfinApiException catch (error) {
      AppLogger.warning(
        'JellyfinLibraryService: Section failed (${error.kind.name}); '
        'returning an empty section.',
      );
      return const [];
    } catch (error, stackTrace) {
      AppLogger.warning(
        'JellyfinLibraryService: Section failed; returning an empty section.',
        error,
        stackTrace,
      );
      return const [];
    }
  }
}
