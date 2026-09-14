import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:m3uxtream_player/features/discovery/api/discovery_api_exception.dart';
import 'package:m3uxtream_player/features/discovery/api/discovery_http_client.dart';

class _StreamingClient extends http.BaseClient {
  _StreamingClient(this.handler);

  final Future<http.StreamedResponse> Function(http.BaseRequest) handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      handler(request);
}

void main() {
  test('absolute timeout cancels a response body that never closes', () async {
    var cancelled = false;
    late final StreamController<List<int>> body;
    body = StreamController<List<int>>(onCancel: () => cancelled = true);
    addTearDown(body.close);
    final client = DiscoveryHttpClient(
      _StreamingClient(
        (request) async =>
            http.StreamedResponse(body.stream, 200, request: request),
      ),
      timeout: const Duration(milliseconds: 25),
    );

    await expectLater(
      client.get(Uri.parse('https://example.test/data')),
      throwsA(
        isA<DiscoveryApiException>().having(
          (error) => error.kind,
          'kind',
          DiscoveryFailureKind.timeout,
        ),
      ),
    );
    expect(cancelled, isTrue);
  });

  test('slow trickle chunks cannot extend the absolute timeout', () async {
    late Timer trickle;
    late final StreamController<List<int>> body;
    body = StreamController<List<int>>(
      onListen: () {
        trickle = Timer.periodic(
          const Duration(milliseconds: 5),
          (_) => body.add(const <int>[32]),
        );
      },
      onCancel: () => trickle.cancel(),
    );
    addTearDown(body.close);
    final client = DiscoveryHttpClient(
      _StreamingClient(
        (request) async =>
            http.StreamedResponse(body.stream, 200, request: request),
      ),
      timeout: const Duration(milliseconds: 30),
    );

    await expectLater(
      client.get(Uri.parse('https://example.test/data')),
      throwsA(
        isA<DiscoveryApiException>().having(
          (error) => error.kind,
          'kind',
          DiscoveryFailureKind.timeout,
        ),
      ),
    );
  });

  test('body limit cancels oversized JSON before decoding', () async {
    var cancelled = false;
    final body = StreamController<List<int>>(onCancel: () => cancelled = true);
    addTearDown(body.close);
    final client = DiscoveryHttpClient(
      _StreamingClient((request) async {
        scheduleMicrotask(() => body.add(utf8.encode('{"value":"large"}')));
        return http.StreamedResponse(body.stream, 200, request: request);
      }),
      maxJsonBytes: 8,
    );

    await expectLater(
      client.get(Uri.parse('https://example.test/data')),
      throwsA(
        isA<DiscoveryApiException>().having(
          (error) => error.kind,
          'kind',
          DiscoveryFailureKind.responseTooLarge,
        ),
      ),
    );
    expect(cancelled, isTrue);
  });

  test(
    'same-origin redirects are followed and cross-origin redirects fail',
    () async {
      var calls = 0;
      final sameOrigin = DiscoveryHttpClient(
        _StreamingClient((request) async {
          calls++;
          if (calls == 1) {
            return http.StreamedResponse(
              const Stream<List<int>>.empty(),
              302,
              headers: const <String, String>{'location': '/next'},
              request: request,
            );
          }
          return http.StreamedResponse(
            Stream<List<int>>.value(utf8.encode('{"ok":true}')),
            200,
            request: request,
          );
        }),
      );

      final response = await sameOrigin.get(
        Uri.parse('https://example.test/start'),
      );
      expect(response.json, containsPair('ok', true));
      expect(calls, 2);

      final crossOrigin = DiscoveryHttpClient(
        _StreamingClient(
          (request) async => http.StreamedResponse(
            const Stream<List<int>>.empty(),
            302,
            headers: const <String, String>{
              'location': 'https://other.test/next',
            },
            request: request,
          ),
        ),
      );
      await expectLater(
        crossOrigin.get(Uri.parse('https://example.test/start')),
        throwsA(
          isA<DiscoveryApiException>().having(
            (error) => error.kind,
            'kind',
            DiscoveryFailureKind.invalidEndpoint,
          ),
        ),
      );
    },
  );
}
