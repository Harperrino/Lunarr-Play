import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/models/streaming_diagnostics.dart';
import 'package:m3uxtream_player/core/services/live_stream_url.dart';
import 'package:m3uxtream_player/core/services/stream_diagnostics_service.dart';

void main() {
  test(
    'probes redirecting HLS streams and classifies valid manifests',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async => server.close(force: true));

      server.listen((request) async {
        if (request.uri.path == '/redirect.m3u8') {
          request.response
            ..statusCode = HttpStatus.found
            ..headers.set(HttpHeaders.locationHeader, '/playlist.m3u8')
            ..write('redirecting')
            ..close();
          return;
        }

        if (request.uri.path == '/playlist.m3u8') {
          request.response
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType(
              'application',
              'vnd.apple.mpegurl',
            )
            ..write('#EXTM3U\n#EXT-X-VERSION:3\n')
            ..close();
          return;
        }

        request.response
          ..statusCode = HttpStatus.notFound
          ..close();
      });

      final result = await StreamDiagnosticsService.probeStreamUrl(
        'http://${server.address.host}:${server.port}/redirect.m3u8',
      );

      expect(result.httpStatus, HttpStatus.ok);
      expect(result.redirected, isTrue);
      expect(result.looksLikeHls, isTrue);
      expect(result.bodySample, contains('#EXTM3U'));
    },
  );

  test('extracts HLS audio rendition and codec hints from manifests', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() async => server.close(force: true));

    server.listen((request) async {
      if (request.uri.path == '/audio-hints.m3u8') {
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType(
            'application',
            'vnd.apple.mpegurl',
          )
          ..write('''
#EXTM3U
#EXT-X-VERSION:7
#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio",NAME="Deutsch",LANGUAGE="de",DEFAULT=YES,AUTOSELECT=YES
#EXT-X-STREAM-INF:BANDWIDTH=2500000,CODECS="avc1.4d401f,mp4a.40.2,ec-3",AUDIO="audio"
video.m3u8
''')
          ..close();
        return;
      }

      request.response
        ..statusCode = HttpStatus.notFound
        ..close();
    });

    final result = await StreamDiagnosticsService.probeStreamUrl(
      'http://${server.address.host}:${server.port}/audio-hints.m3u8',
    );

    expect(result.looksLikeHls, isTrue);
    expect(result.hlsAudioRenditions, hasLength(1));
    expect(result.hlsCodecs, containsAll(['AAC', 'E-AC-3']));
    expect(result.hlsHintSummary, contains('AUDIO='));
    expect(result.hlsHintSummary, contains('CODECS='));
  });

  test('detects fast extensionless HLS within one shared budget', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() async => server.close(force: true));

    server.listen((request) async {
      request.response.headers.contentType = ContentType(
        'application',
        'vnd.apple.mpegurl',
      );
      if (request.method == 'GET') {
        request.response.write('#EXTM3U\n#EXT-X-VERSION:3\n');
      }
      await request.response.close();
    });

    final result = await StreamDiagnosticsService.probeStreamUrl(
      'http://${server.address.host}:${server.port}/live/user/pass/123',
      timeout: const Duration(milliseconds: 1200),
    );

    expect(result.timedOut, isFalse);
    expect(result.looksLikeHls, isTrue);
    expect(result.bodySample, contains('#EXTM3U'));
  });

  test('HEAD and fallback GET share one end-to-end budget', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() async => server.close(force: true));

    server.listen((request) async {
      await Future<void>.delayed(const Duration(milliseconds: 140));
      request.response.statusCode = request.method == 'HEAD'
          ? HttpStatus.methodNotAllowed
          : HttpStatus.ok;
      if (request.method == 'GET') {
        request.response.write('#EXTM3U\n');
      }
      await request.response.close();
    });

    final stopwatch = Stopwatch()..start();
    final result = await StreamDiagnosticsService.probeStreamUrl(
      'http://${server.address.host}:${server.port}/live/user/pass/123',
      timeout: const Duration(milliseconds: 200),
    );
    stopwatch.stop();

    expect(result.timedOut, isTrue);
    expect(stopwatch.elapsed, lessThan(const Duration(milliseconds: 350)));
  });

  test('redirects cannot multiply the end-to-end budget', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() async => server.close(force: true));

    server.listen((request) async {
      await Future<void>.delayed(const Duration(milliseconds: 90));
      final step = int.tryParse(request.uri.pathSegments.last) ?? 0;
      request.response
        ..statusCode = HttpStatus.found
        ..headers.set(HttpHeaders.locationHeader, '/redirect/${step + 1}');
      await request.response.close();
    });

    final stopwatch = Stopwatch()..start();
    final result = await StreamDiagnosticsService.probeStreamUrl(
      'http://${server.address.host}:${server.port}/redirect/0',
      timeout: const Duration(milliseconds: 180),
    );
    stopwatch.stop();

    expect(result.timedOut, isTrue);
    expect(stopwatch.elapsed, lessThan(const Duration(milliseconds: 330)));
  });

  test('manifest body read respects the shared budget', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() async => server.close(force: true));

    server.listen((request) async {
      request.response.headers.contentType = ContentType(
        'application',
        'vnd.apple.mpegurl',
      );
      if (request.method == 'GET') {
        await request.response.flush();
        await Future<void>.delayed(const Duration(milliseconds: 400));
        request.response.write('#EXTM3U\n');
      }
      await request.response.close();
    });

    final stopwatch = Stopwatch()..start();
    final result = await StreamDiagnosticsService.probeStreamUrl(
      'http://${server.address.host}:${server.port}/live/user/pass/123',
      timeout: const Duration(milliseconds: 150),
    );
    stopwatch.stop();

    expect(result.timedOut, isTrue);
    expect(stopwatch.elapsed, lessThan(const Duration(milliseconds: 300)));
  });

  test('advisory timeout keeps an extensionless source continuous', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() async => server.close(force: true));

    server.listen((request) async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await request.response.close();
    });

    final url =
        'http://${server.address.host}:${server.port}/live/user/pass/123';
    final result = await StreamDiagnosticsService.probeStreamUrl(
      url,
      timeout: const Duration(milliseconds: 80),
    );

    expect(result.timedOut, isTrue);
    expect(result.looksLikeHls, isFalse);
    expect(
      LiveStreamUrl.deliveryFor(url, looksLikeHls: result.looksLikeHls),
      LiveStreamDelivery.continuous,
    );
  });

  test('classifies invalid HLS bodies as possible invalidHls', () {
    final result = StreamConnectionProbeResult(
      requestedUri: Uri.parse('http://example.com/playlist.m3u8'),
      resolvedUri: Uri.parse('http://example.com/playlist.m3u8'),
      duration: Duration.zero,
      redirectChain: const [],
      usedHead: false,
      usedRange: true,
      httpStatus: HttpStatus.ok,
      contentType: 'application/vnd.apple.mpegurl',
      bodySample: '#NOT-A-MANIFEST',
    );

    final classification = StreamDiagnosticsService.classifyFailure(
      probe: result,
    );
    expect(classification.kind, StreamingFailureKind.invalidHls);
    expect(classification.possible, isTrue);
  });

  test('classifies socket and codec style failures', () {
    final offline = StreamDiagnosticsService.classifyFailure(
      error: const SocketException('Connection refused'),
    );
    expect(offline.kind, StreamingFailureKind.offline);

    final codec = StreamDiagnosticsService.classifyFailure(
      error: 'unsupported codec',
    );
    expect(codec.kind, StreamingFailureKind.unsupportedCodec);
  });

  test('classifies timeout exceptions as timeout', () {
    final timeout = StreamDiagnosticsService.classifyFailure(
      error: TimeoutException('live open timed out'),
    );

    expect(timeout.kind, StreamingFailureKind.timeout);
    expect(timeout.possible, isFalse);
  });

  test('classifies redirect loops as redirect issues', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() async => server.close(force: true));

    server.listen((request) async {
      request.response
        ..statusCode = HttpStatus.found
        ..headers.set(HttpHeaders.locationHeader, '/loop.m3u8')
        ..write('looping')
        ..close();
    });

    final result = await StreamDiagnosticsService.probeStreamUrl(
      'http://${server.address.host}:${server.port}/loop.m3u8',
    );

    expect(result.redirectLimitExceeded, isTrue);
    expect(
      StreamDiagnosticsService.classifyFailure(probe: result).kind,
      StreamingFailureKind.redirectIssue,
    );
  });
}
