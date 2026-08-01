import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:m3uxtream_player/features/jellyfin/api/jellyfin_api_client.dart';
import 'package:m3uxtream_player/features/jellyfin/auth/jellyfin_connection.dart';
import 'package:m3uxtream_player/features/jellyfin/auth/jellyfin_credentials_store.dart';
import 'package:m3uxtream_player/features/jellyfin/playback/jellyfin_player_controller.dart';
import 'package:m3uxtream_player/features/jellyfin/providers/jellyfin_connection_providers.dart';
import 'package:m3uxtream_player/features/jellyfin/providers/jellyfin_playback_providers.dart';

const jellyfinTestConnection = JellyfinConnection(
  baseUrl: 'http://server:8096',
  serverId: 'server-id-1',
  serverVersion: '10.10.3',
  userId: 'user-id-1',
  username: 'alice',
  accessToken: 'token-abc-123',
  deviceId: 'device-42',
);

/// Connection whose stream host refuses connections instantly, so real mpv
/// open attempts fail fast instead of hanging on DNS.
const jellyfinOfflineTestConnection = JellyfinConnection(
  baseUrl: 'http://127.0.0.1:1',
  serverId: 'server-id-1',
  serverVersion: '10.10.3',
  userId: 'user-id-1',
  username: 'alice',
  accessToken: 'token-abc-123',
  deviceId: 'device-42',
);

Map<String, dynamic> jellyfinMovieJson({
  String id = 'movie-1',
  String name = 'Test Movie',
  int? year = 2024,
  int runtimeTicks = 5400000000,
  int positionTicks = 0,
  bool played = false,
  String? overview = 'A test movie overview.',
}) {
  return {
    'Id': id,
    'Name': name,
    'Type': 'Movie',
    'ProductionYear': year,
    'RunTimeTicks': runtimeTicks,
    'Overview': overview,
    'ImageTags': <String, dynamic>{},
    'UserData': <String, dynamic>{
      'PlaybackPositionTicks': positionTicks,
      'Played': played,
    },
    'UnknownFutureField': 'ignored-by-parser',
  };
}

Map<String, dynamic> jellyfinSeriesJson({
  String id = 'series-1',
  String name = 'Test Series',
  int? year = 2023,
}) {
  return {
    'Id': id,
    'Name': name,
    'Type': 'Series',
    'ProductionYear': year,
    'Overview': 'A test series overview.',
    'ImageTags': <String, dynamic>{},
    'UserData': <String, dynamic>{'PlaybackPositionTicks': 0, 'Played': false},
  };
}

Map<String, dynamic> jellyfinEpisodeJson({
  String id = 'episode-1',
  String name = 'Test Episode',
  int season = 1,
  int episode = 2,
  int runtimeTicks = 2400000000,
  int positionTicks = 0,
}) {
  return {
    'Id': id,
    'Name': name,
    'Type': 'Episode',
    'SeriesName': 'Test Series',
    'ParentIndexNumber': season,
    'IndexNumber': episode,
    'RunTimeTicks': runtimeTicks,
    'Overview': 'An episode overview.',
    'ImageTags': <String, dynamic>{},
    'UserData': <String, dynamic>{
      'PlaybackPositionTicks': positionTicks,
      'Played': false,
    },
  };
}

Map<String, dynamic> jellyfinLibraryJson({
  String id = 'library-1',
  String name = 'Movies',
  String collectionType = 'movies',
}) {
  return {
    'Id': id,
    'Name': name,
    'CollectionType': collectionType,
    'ImageTags': <String, dynamic>{},
  };
}

/// Mock handler serving a happy-path Jellyfin server.
///
/// Set [failResume], [failViews] or [failLibraryItems] to simulate broken
/// endpoints.
MockClientHandler jellyfinHappyHandler({
  bool failViews = false,
  bool failResume = false,
  bool failNextUp = false,
  bool failLatest = false,
  bool failLibraryItems = false,
  bool failDetail = false,
  bool failEpisodes = false,
  bool failPlaybackInfo = false,
}) {
  return (request) async {
    final path = request.url.path;

    if (path.endsWith('/PlaybackInfo')) {
      return failPlaybackInfo
          ? http.Response('nope', 500)
          : http.Response(
              jsonEncode({
                'MediaSources': [
                  {
                    'Id': 'ms-1',
                    'Container': 'mp4',
                    'SupportsDirectPlay': true,
                    'SupportsDirectStream': false,
                    'SupportsTranscoding': false,
                  },
                ],
                'PlaySessionId': 'ps-1',
              }),
              200,
            );
    }
    if (path.endsWith('/Users/user-id-1/Views')) {
      return failViews
          ? http.Response('nope', 500)
          : http.Response(
              jsonEncode({
                'Items': [
                  jellyfinLibraryJson(),
                  jellyfinLibraryJson(
                    id: 'library-2',
                    name: 'TV Shows',
                    collectionType: 'tvshows',
                  ),
                ],
              }),
              200,
            );
    }
    if (path.endsWith('/Users/user-id-1/Items/Resume')) {
      return failResume
          ? http.Response('nope', 500)
          : http.Response(
              jsonEncode({
                'Items': [
                  jellyfinMovieJson(positionTicks: 2700000000),
                ],
              }),
              200,
            );
    }
    if (path.endsWith('/Shows/NextUp')) {
      return failNextUp
          ? http.Response('nope', 500)
          : http.Response(
              jsonEncode({'Items': [jellyfinEpisodeJson()]}),
              200,
            );
    }
    if (path.endsWith('/Users/user-id-1/Items/Latest')) {
      return failLatest
          ? http.Response('nope', 500)
          : http.Response(
              jsonEncode([jellyfinMovieJson(id: 'movie-2', name: 'New Movie')]),
              200,
            );
    }
    if (path.contains('/Shows/') && path.endsWith('/Episodes')) {
      return failEpisodes
          ? http.Response('nope', 500)
          : http.Response(
              jsonEncode({
                'Items': [
                  jellyfinEpisodeJson(),
                  jellyfinEpisodeJson(id: 'episode-2', episode: 1),
                ],
              }),
              200,
            );
    }
    if (RegExp(r'/Users/user-id-1/Items/[^/]+$').hasMatch(path)) {
      final itemId = path.split('/').last;
      final body = switch (itemId) {
        'series-1' => jellyfinSeriesJson(),
        'episode-1' => jellyfinEpisodeJson(),
        _ => jellyfinMovieJson(),
      };
      return failDetail
          ? http.Response('nope', 500)
          : http.Response(jsonEncode(body), 200);
    }
    if (path.endsWith('/Users/user-id-1/Items')) {
      return failLibraryItems
          ? http.Response('nope', 500)
          : http.Response(
              jsonEncode({
                'Items': [
                  jellyfinMovieJson(),
                  jellyfinSeriesJson(),
                ],
              }),
              200,
            );
    }
    return http.Response('not found', 404);
  };
}

/// [jellyfinHappyHandler] wrapped in a [MockClient].
MockClient jellyfinHappyTransport({
  bool failViews = false,
  bool failResume = false,
  bool failNextUp = false,
  bool failLatest = false,
  bool failLibraryItems = false,
  bool failDetail = false,
  bool failEpisodes = false,
  bool failPlaybackInfo = false,
}) {
  return MockClient(
    jellyfinHappyHandler(
      failViews: failViews,
      failResume: failResume,
      failNextUp: failNextUp,
      failLatest: failLatest,
      failLibraryItems: failLibraryItems,
      failDetail: failDetail,
      failEpisodes: failEpisodes,
      failPlaybackInfo: failPlaybackInfo,
    ),
  );
}

/// Handler serving empty home sections (no resume, no libraries, ...).
MockClientHandler jellyfinEmptyHandler() {
  return (request) async {
    final path = request.url.path;
    if (path.endsWith('/Users/user-id-1/Views') ||
        path.endsWith('/Users/user-id-1/Items/Resume') ||
        path.endsWith('/Shows/NextUp')) {
      return http.Response('{"Items": []}', 200);
    }
    if (path.endsWith('/Users/user-id-1/Items/Latest')) {
      return http.Response('[]', 200);
    }
    return http.Response('not found', 404);
  };
}

class _AuthedSessionController extends JellyfinSessionController {
  _AuthedSessionController(this._connection);

  final JellyfinConnection _connection;

  @override
  JellyfinSessionState build() =>
      JellyfinAuthenticated(connection: _connection);
}

/// Hosts a Jellyfin widget with an authenticated session and a mock transport.
///
/// [playbackControllerOverride] replaces the real autoDispose player provider
/// so non-native tests never construct a real media_kit player.
Widget jellyfinTestHost(
  Widget child, {
  MockClient? transport,
  JellyfinConnection? connection,
  JellyfinPlayerController? playbackControllerOverride,
}) {
  final overrides = jellyfinTestOverrides(
    transport: transport,
    connection: connection,
  );
  if (playbackControllerOverride != null) {
    overrides.add(
      jellyfinPlayerControllerProvider.overrideWith((ref) {
        ref.onDispose(
          () => unawaited(playbackControllerOverride.disposeAsync()),
        );
        return playbackControllerOverride;
      }),
    );
  }
  return ProviderScope(
    overrides: overrides,
    key: UniqueKey(),
    child: MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: Scaffold(body: child),
    ),
  );
}

/// Overrides pairing an authenticated session with a mock transport.
List<Override> jellyfinTestOverrides({
  MockClient? transport,
  JellyfinConnection? connection,
}) {
  return [
    jellyfinApiClientProvider.overrideWithValue(
      JellyfinApiClient(transport: transport ?? jellyfinHappyTransport()),
    ),
    jellyfinCredentialsStoreProvider.overrideWithValue(
      InMemoryJellyfinCredentialsStore(),
    ),
    jellyfinSessionControllerProvider.overrideWith(
      () => _AuthedSessionController(connection ?? jellyfinTestConnection),
    ),
  ];
}

/// Tall viewport so lazy lists render shelves below the fold.
void jellyfinTallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1280, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
