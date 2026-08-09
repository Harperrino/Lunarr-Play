import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:m3uxtream_player/features/jellyfin/api/jellyfin_api_client.dart';
import 'package:m3uxtream_player/features/jellyfin/playback/jellyfin_playback_reporter.dart';

import 'jellyfin_test_helpers.dart';

void main() {
  test('reports start, throttles progress, forces state changes and stops', () async {
    var now = DateTime(2026, 8, 1, 12);
    final requests = <http.Request>[];
    final reporter = JellyfinPlaybackReporter(
      apiClient: JellyfinApiClient(
        transport: MockClient((request) async {
          requests.add(request);
          return http.Response('', 204);
        }),
      ),
      now: () => now,
    );
    const session = JellyfinPlaybackSession(
      itemId: 'movie-1',
      mediaSourceId: 'ms-1',
      playSessionId: 'ps-1',
    );

    await reporter.reportPlaybackStart(
      connection: jellyfinTestConnection,
      session: session,
      position: const Duration(seconds: 90),
    );

    expect(requests, hasLength(1));
    expect(requests.single.url.path, '/Sessions/Playing');
    expect(requests.single.headers['X-Emby-Token'], 'token-abc-123');
    final startBody = jsonDecode(requests.single.body) as Map<String, dynamic>;
    expect(startBody['ItemId'], 'movie-1');
    expect(startBody['MediaSourceId'], 'ms-1');
    expect(startBody['PlaySessionId'], 'ps-1');
    expect(startBody['PositionTicks'], 900000000);
    expect(startBody['IsPaused'], isFalse);

    now = now.add(const Duration(seconds: 5));
    await reporter.reportPlaybackProgress(
      connection: jellyfinTestConnection,
      session: session,
      position: const Duration(seconds: 95),
      isPaused: false,
    );
    expect(requests, hasLength(1));

    now = now.add(const Duration(seconds: 6));
    await reporter.reportPlaybackProgress(
      connection: jellyfinTestConnection,
      session: session,
      position: const Duration(seconds: 101),
      isPaused: false,
    );
    expect(requests, hasLength(2));
    expect(requests.last.url.path, '/Sessions/Playing/Progress');

    await reporter.reportPlaybackProgress(
      connection: jellyfinTestConnection,
      session: session,
      position: const Duration(seconds: 101),
      isPaused: true,
      force: true,
    );
    expect(requests, hasLength(3));

    await reporter.reportPlaybackStopped(
      connection: jellyfinTestConnection,
      session: session,
      position: const Duration(seconds: 101),
      isPaused: true,
    );
    expect(requests, hasLength(4));
    expect(requests.last.url.path, '/Sessions/Playing/Stopped');
  });

  test('reporting failures never escape to the playback caller', () async {
    final reporter = JellyfinPlaybackReporter(
      apiClient: JellyfinApiClient(
        transport: MockClient((_) async => http.Response('failed', 503)),
      ),
    );
    const session = JellyfinPlaybackSession(
      itemId: 'movie-1',
      mediaSourceId: 'ms-1',
    );

    await expectLater(
      reporter.reportPlaybackStart(
        connection: jellyfinTestConnection,
        session: session,
      ),
      completes,
    );
    await expectLater(
      reporter.reportPlaybackStopped(
        connection: jellyfinTestConnection,
        session: session,
        position: Duration.zero,
        isPaused: false,
      ),
      completes,
    );
  });
}
