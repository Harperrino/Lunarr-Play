import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:m3uxtream_player/features/discovery/api/discovery_api_exception.dart';
import 'package:m3uxtream_player/features/discovery/api/discovery_http_client.dart';
import 'package:m3uxtream_player/features/discovery/api/seerr_discovery_client.dart';
import 'package:m3uxtream_player/features/discovery/api/tmdb_discovery_client.dart';
import 'package:m3uxtream_player/features/discovery/models/discovery_models.dart';

void main() {
  const locale = DiscoveryLocale(language: 'de', region: 'DE');

  group('TMDB adapter', () {
    test(
      'search keeps adult media, removes people, and authenticates by header',
      () async {
        http.Request? captured;
        final transport = MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode(<String, Object?>{
              'page': 1,
              'total_pages': 1,
              'results': <Object?>[
                <String, Object?>{
                  'id': 10,
                  'media_type': 'movie',
                  'title': 'Adult movie',
                  'adult': true,
                },
                <String, Object?>{
                  'id': 11,
                  'media_type': 'person',
                  'name': 'Person result',
                },
              ],
            }),
            200,
          );
        });
        final client = TmdbDiscoveryClient(
          httpClient: DiscoveryHttpClient(transport),
          readAccessToken: 'fixture-token',
        );

        final result = await client.search('query', locale: locale);

        expect(result.items, hasLength(1));
        expect(result.items.single.adult, isTrue);
        expect(captured!.url.path, '/3/search/multi');
        expect(captured!.url.queryParameters['include_adult'], 'true');
        expect(captured!.url.queryParameters['language'], 'de-DE');
        expect(captured!.headers['Authorization'], 'Bearer fixture-token');
        expect(captured!.url.toString(), isNot(contains('fixture-token')));
      },
    );

    test('home uses the official list endpoints', () async {
      final paths = <String>[];
      final transport = MockClient((request) async {
        paths.add(request.url.path);
        return http.Response(
          jsonEncode(<String, Object?>{
            'page': 1,
            'total_pages': 1,
            'results': <Object?>[
              <String, Object?>{
                'id': paths.length,
                'media_type': request.url.path.contains('/tv/')
                    ? 'tv'
                    : 'movie',
                'title': 'Movie ${paths.length}',
                'name': 'Series ${paths.length}',
                'adult': true,
                'vote_average': 8.0,
              },
            ],
          }),
          200,
        );
      });
      final client = TmdbDiscoveryClient(
        httpClient: DiscoveryHttpClient(transport),
        readAccessToken: 'fixture-token',
      );

      final feed = await client.fetchHome(locale);

      expect(
        paths.toSet(),
        containsAll(<String>{
          '/3/trending/all/day',
          '/3/movie/popular',
          '/3/tv/popular',
          '/3/movie/upcoming',
          '/3/tv/on_the_air',
          '/3/movie/top_rated',
          '/3/tv/top_rated',
        }),
      );
      expect(feed.shelves, hasLength(5));
      expect(
        feed.shelves.expand((shelf) => shelf.items).every((item) => item.adult),
        isTrue,
      );
    });

    test(
      'top-rated category merges, deduplicates and preserves pagination',
      () async {
        final transport = MockClient((request) async {
          final movie = request.url.path.endsWith('/movie/top_rated');
          return http.Response(
            jsonEncode(<String, Object?>{
              'page': 3,
              'total_pages': movie ? 8 : 12,
              'results': <Object?>[
                <String, Object?>{
                  'id': movie ? 1 : 2,
                  'title': movie ? 'Movie' : null,
                  'name': movie ? null : 'Series',
                  'vote_average': movie ? 7.5 : 9.0,
                },
                if (movie)
                  <String, Object?>{
                    'id': 1,
                    'title': 'Duplicate movie',
                    'vote_average': 7.0,
                  },
              ],
            }),
            200,
          );
        });
        final client = TmdbDiscoveryClient(
          httpClient: DiscoveryHttpClient(transport),
          readAccessToken: 'fixture-token',
        );

        final page = await client.fetchCategory(
          DiscoveryShelfKind.topRated,
          locale: locale,
          page: 3,
        );

        expect(page.page, 3);
        expect(page.totalPages, 12);
        expect(page.items.map((item) => item.title), <String>[
          'Series',
          'Movie',
        ]);
      },
    );

    test(
      'details select localized or English trailers without blocking data',
      () async {
        final videoLanguages = <String>[];
        final transport = MockClient((request) async {
          if (request.url.path.endsWith('/videos')) {
            final language = request.url.queryParameters['language']!;
            videoLanguages.add(language);
            return http.Response(
              jsonEncode(<String, Object?>{
                'results': <Object?>[
                  <String, Object?>{
                    'key': language == 'en-US' ? 'English1' : 'German01',
                    'site': 'YouTube',
                    'name': language == 'en-US' ? 'Official trailer' : 'Teaser',
                    'type': language == 'en-US' ? 'Trailer' : 'Teaser',
                    'official': true,
                    'iso_639_1': language.substring(0, 2),
                  },
                ],
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode(<String, Object?>{
              'id': 77,
              'title': 'Movie details',
              'overview': 'Details',
            }),
            200,
          );
        });
        final client = TmdbDiscoveryClient(
          httpClient: DiscoveryHttpClient(transport),
          readAccessToken: 'fixture-token',
        );

        final details = await client.fetchDetails(
          const DiscoveryMediaItem(
            id: 77,
            mediaType: DiscoveryMediaType.movie,
            title: 'Movie',
          ),
          locale: locale,
        );

        expect(videoLanguages, containsAll(<String>['de-DE', 'en-US']));
        expect(details.trailers, hasLength(2));
        expect(details.trailers.first.title, 'Official trailer');
        expect(details.trailers.first.validatedWatchUri?.scheme, 'https');
      },
    );
  });

  group('Seerr adapter', () {
    test(
      'normalizes base paths without discarding the reverse-proxy prefix',
      () {
        expect(
          normalizeSeerrApiBase('https://example.test/seerr').toString(),
          'https://example.test/seerr/api/v1',
        );
        expect(
          normalizeSeerrApiBase('http://192.168.1.5:5055/api/v1/').toString(),
          'http://192.168.1.5:5055/api/v1',
        );
      },
    );

    test(
      'enforces version, sends season request, and keeps adult metadata',
      () async {
        http.Request? requestCall;
        final transport = MockClient((request) async {
          if (request.url.path.endsWith('/status')) {
            return http.Response(
              jsonEncode(<String, Object?>{'version': '3.1.0'}),
              200,
            );
          }
          if (request.method == 'POST' &&
              request.url.path.endsWith('/request')) {
            requestCall = request;
            return http.Response(jsonEncode(<String, Object?>{'id': 99}), 201);
          }
          if (request.url.path.endsWith('/tv/55')) {
            return http.Response(
              jsonEncode(<String, Object?>{
                'id': 55,
                'mediaType': 'tv',
                'name': 'Requested series',
                'adult': true,
                'mediaInfo': <String, Object?>{'status': 2},
              }),
              200,
            );
          }
          return http.Response('{}', 404);
        });
        final client = SeerrDiscoveryClient(
          httpClient: DiscoveryHttpClient(transport),
          endpoint: 'https://example.test/seerr',
          apiKey: 'fixture-admin-key',
        );
        const item = DiscoveryMediaItem(
          id: 55,
          mediaType: DiscoveryMediaType.tv,
          title: 'Requested series',
        );

        final result = await client.requestMedia(
          item,
          locale: locale,
          seasons: const <int>[1, 3],
        );

        expect(result.adult, isTrue);
        expect(result.availability, DiscoveryAvailability.pending);
        expect(requestCall!.url.path, '/seerr/api/v1/request');
        expect(requestCall!.headers['X-Api-Key'], 'fixture-admin-key');
        expect(
          jsonDecode(requestCall!.body),
          containsPair('seasons', <int>[1, 3]),
        );
        expect(
          requestCall!.url.toString(),
          isNot(contains('fixture-admin-key')),
        );
      },
    );

    test('rejects servers older than 3.1.0 before discovery', () async {
      final transport = MockClient(
        (_) async => http.Response(
          jsonEncode(<String, Object?>{'version': '3.0.1'}),
          200,
        ),
      );
      final client = SeerrDiscoveryClient(
        httpClient: DiscoveryHttpClient(transport),
        endpoint: 'https://example.test',
        apiKey: 'fixture-admin-key',
      );

      await expectLater(
        client.testConnection(),
        throwsA(
          isA<DiscoveryApiException>().having(
            (error) => error.kind,
            'kind',
            DiscoveryFailureKind.unsupportedVersion,
          ),
        ),
      );
    });

    test('maps rejected administrator keys to unauthorized', () async {
      final transport = MockClient((request) async {
        if (request.url.path.endsWith('/status')) {
          return http.Response(
            jsonEncode(<String, Object?>{'version': '3.1.0'}),
            200,
          );
        }
        return http.Response('{}', 401);
      });
      final client = SeerrDiscoveryClient(
        httpClient: DiscoveryHttpClient(transport),
        endpoint: 'https://example.test',
        apiKey: 'invalid-fixture-key',
      );

      await expectLater(
        client.testConnection(),
        throwsA(
          isA<DiscoveryApiException>().having(
            (error) => error.kind,
            'kind',
            DiscoveryFailureKind.unauthorized,
          ),
        ),
      );
    });

    test('details parse valid related videos and reject unsafe URLs', () async {
      final transport = MockClient((request) async {
        if (request.url.path.endsWith('/status')) {
          return http.Response(
            jsonEncode(<String, Object?>{'version': '3.1.0'}),
            200,
          );
        }
        return http.Response(
          jsonEncode(<String, Object?>{
            'id': 88,
            'mediaType': 'movie',
            'title': 'Seerr movie',
            'relatedVideos': <Object?>[
              <String, Object?>{
                'site': 'YouTube',
                'key': 'Trailer88',
                'url': 'https://www.youtube.com/watch?v=Trailer88',
                'name': 'Trailer',
                'type': 'Trailer',
              },
              <String, Object?>{'url': 'javascript:alert(1)', 'name': 'Unsafe'},
            ],
          }),
          200,
        );
      });
      final client = SeerrDiscoveryClient(
        httpClient: DiscoveryHttpClient(transport),
        endpoint: 'https://example.test',
        apiKey: 'fixture-admin-key',
      );

      final details = await client.fetchDetails(
        const DiscoveryMediaItem(
          id: 88,
          mediaType: DiscoveryMediaType.movie,
          title: 'Movie',
        ),
        locale: locale,
      );

      expect(details.trailers, hasLength(1));
      expect(
        details.trailers.single.provider,
        DiscoveryTrailerProvider.youtube,
      );
    });
  });
}
