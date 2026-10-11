import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:m3uxtream_player/core/services/release_update_service.dart';

Map<String, Object> release(
  String tag, {
  bool prerelease = false,
  bool draft = false,
}) => {
  'tag_name': tag,
  'prerelease': prerelease,
  'draft': draft,
  'html_url': 'https://example.invalid/untrusted',
};

void main() {
  test('full release is newer than its RC; build metadata is ignored', () {
    final update = newerFullRelease('1.0.3-rc.5', release('v1.0.3'));
    expect(update?.version, '1.0.3');
    expect(
      update?.url.toString(),
      'https://github.com/Harperrino/Lunarr-Play/releases/tag/v1.0.3',
    );
    expect(newerFullRelease('1.0.3+11', release('v1.0.3+12')), isNull);
    expect(newerFullRelease('1.0.3-rc.5', release('v1.0.2')), isNull);
    expect(newerFullRelease('1.0.9', release('v1.0.10')), isNotNull);
  });
  test('RCs, drafts and malformed responses cannot advertise an update', () {
    for (final payload in [
      release('v2.0.0', prerelease: true),
      release('v2.0.0', draft: true),
      release('v2.0.0-rc.1'),
      release('bad-tag'),
      {},
      [],
      null,
    ]) {
      expect(newerFullRelease('1.0.2', payload), isNull);
    }
    expect(newerFullRelease('unknown', release('v2.0.0')), isNull);
  });
  for (final status in [200, 404, 403, 500]) {
    test(
      'exactly one request per lifetime, including HTTP $status failures',
      () async {
        var requests = 0;
        final service = ReleaseUpdateService(
          currentVersion: () async => '1.0.2',
          client: MockClient((request) async {
            requests++;
            expect(
              request.url.toString(),
              'https://api.github.com/repos/Harperrino/Lunarr-Play/releases/latest',
            );
            expect(request.headers.containsKey('authorization'), isFalse);
            return http.Response(jsonEncode(release('v1.0.3')), status);
          }),
        );
        final results = await Future.wait([
          service.checkOnce(),
          service.checkOnce(),
          service.checkOnce(),
        ]);
        expect(requests, 1);
        expect(results.first != null, status == 200);
        await service.checkOnce();
        expect(requests, 1);
      },
    );
  }
  test(
    'network and malformed JSON failures remain silent and do not retry',
    () async {
      for (final malformed in [false, true]) {
        var calls = 0;
        final service = ReleaseUpdateService(
          currentVersion: () async => '1.0.2',
          client: MockClient((_) async {
            calls++;
            if (!malformed) throw http.ClientException('offline');
            return http.Response('not-json', 200);
          }),
        );
        expect(await service.checkOnce(), isNull);
        expect(await service.checkOnce(), isNull);
        expect(calls, 1);
      }
    },
  );
}
