import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/features/jellyfin/services/jellyfin_log_redactor.dart';

void main() {
  const redactor = JellyfinLogRedactor();

  test('redacts X-Emby-Token header values', () {
    final result = redactor.redact(
      'Sending request with X-Emby-Token: 12345abcSECRET to /Items.',
    );
    expect(result, contains('X-Emby-Token: ***'));
    expect(result, isNot(contains('12345abcSECRET')));
  });

  test('redacts X-Emby-Authorization header values', () {
    final result = redactor.redact(
      'Header: X-Emby-Authorization: MediaBrowser Client="Lunarr", DeviceId="d1", Token="tok-9"',
    );
    expect(result, isNot(contains('tok-9')));
    expect(result, contains('***'));
  });

  test('redacts Token assignments inside authorization values', () {
    final result = redactor.redact('Token="abc123" is used');
    expect(result, isNot(contains('abc123')));
    expect(result, contains('Token="***"'));
  });

  test('redacts api_key and token query parameters', () {
    for (final url in [
      'http://server:8096/videos/1/stream?api_key=secret-token-1&Static=true',
      'http://server:8096/videos/1/stream?Static=true&token=secret-token-2',
      'http://server:8096/videos/1/stream?access_token=secret-token-3',
    ]) {
      final result = redactor.redact('Opening $url');
      expect(result, isNot(contains('secret-token')));
      expect(result, contains('***'));
    }
  });

  test('redacts password JSON payloads', () {
    final result = redactor.redact(
      'Body: {"Username":"admin","Pw":"hunter2-secret","Password":"x"}',
    );
    expect(result, isNot(contains('hunter2-secret')));
    expect(result, isNot(contains('"Pw":"x"')));
    expect(result, isNot(contains('"Password":"x"')));
  });

  test('keeps allowed server metadata and status codes', () {
    final result = redactor.redact(
      'JellyfinApiClient: Public system info received: "My Server" (version 10.10.0). GET /System/Info/Public → 200.',
    );
    expect(result, contains('My Server'));
    expect(result, contains('10.10.0'));
    expect(result, contains('200'));
  });
}
