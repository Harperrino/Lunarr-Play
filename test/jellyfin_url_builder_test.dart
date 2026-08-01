import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/features/jellyfin/api/jellyfin_api_exception.dart';
import 'package:m3uxtream_player/features/jellyfin/api/jellyfin_url_builder.dart';

void main() {
  const builder = JellyfinUrlBuilder();

  group('normalizeBaseUrl', () {
    test('trims whitespace and strips trailing slashes', () {
      expect(builder.normalizeBaseUrl('  https://server:8096///  '), 'https://server:8096');
      expect(builder.normalizeBaseUrl('http://server/'), 'http://server');
    });

    test('prepends http when no scheme is given', () {
      expect(builder.normalizeBaseUrl('server:8096'), 'http://server:8096');
      expect(builder.normalizeBaseUrl('192.168.1.10:8096'), 'http://192.168.1.10:8096');
    });

    test('keeps https and an explicit reverse-proxy path', () {
      expect(builder.normalizeBaseUrl('https://media.example.com/jellyfin'), 'https://media.example.com/jellyfin');
    });

    test('rejects empty input', () {
      expect(
        () => builder.normalizeBaseUrl('   '),
        throwsA(isA<JellyfinApiException>().having(
          (e) => e.kind,
          'kind',
          JellyfinFailureKind.invalidUrl,
        )),
      );
    });

    test('rejects unsupported schemes', () {
      expect(
        () => builder.normalizeBaseUrl('ftp://server'),
        throwsA(isA<JellyfinApiException>().having(
          (e) => e.kind,
          'kind',
          JellyfinFailureKind.invalidUrl,
        )),
      );
    });

    test('rejects credentialed URLs and embedded whitespace', () {
      expect(
        () => builder.normalizeBaseUrl('http://user:pass@server:8096'),
        throwsA(isA<JellyfinApiException>()),
      );
      expect(
        () => builder.normalizeBaseUrl('http://ser ver:8096'),
        throwsA(isA<JellyfinApiException>()),
      );
    });

    test('rejects host-less URLs', () {
      expect(
        () => builder.normalizeBaseUrl('http://'),
        throwsA(isA<JellyfinApiException>()),
      );
    });
  });

  group('endpoints', () {
    test('builds system info, authenticate and logout endpoints', () {
      expect(
        builder.systemInfoPublic('http://server:8096').toString(),
        'http://server:8096/System/Info/Public',
      );
      expect(
        builder.authenticateByName('http://server:8096').toString(),
        'http://server:8096/Users/AuthenticateByName',
      );
      expect(
        builder.sessionsLogout('http://server:8096').toString(),
        'http://server:8096/Sessions/Logout',
      );
    });
  });
}
