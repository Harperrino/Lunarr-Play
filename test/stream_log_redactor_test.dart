import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/services/stream_log_redactor.dart';

void main() {
  test('redacts xtream credentials in path, query, and user info', () {
    final redacted = redactStreamUrl(
      'http://user:pass@iptv.example.com/live/user/pass/123?username=alice&token=abc&quality=720',
    );

    expect(redacted, contains('iptv.example.com'));
    expect(redacted, contains('123'));
    expect(redacted, isNot(contains('user:pass')));
    expect(redacted, isNot(contains('alice')));
    expect(redacted, isNot(contains('abc')));
  });

  test('redacts URLs embedded in log text', () {
    final redacted = redactStreamText(
      'Failed to open http://name:secret@host/live/name/secret/456?password=abc',
    );

    expect(redacted, contains('host'));
    expect(redacted, isNot(contains('secret')));
    expect(redacted, isNot(contains('password=abc')));
  });

  test(
    'redacts xtream movie and series paths plus basic auth and query secrets',
    () {
      final movie = redactStreamUrl(
        'http://user:pass@iptv.example.com/movie/user/pass/456?auth=abc&session=xyz',
      );
      final series = redactStreamUrl(
        'http://iptv.example.com/series/user/pass/789?token=abc&password=def',
      );

      expect(movie, isNot(contains('user:pass')));
      expect(movie, isNot(contains('/user/pass/')));
      expect(movie, isNot(contains('auth=abc')));
      expect(movie, isNot(contains('session=xyz')));

      expect(series, isNot(contains('/user/pass/')));
      expect(series, isNot(contains('token=abc')));
      expect(series, isNot(contains('password=def')));
    },
  );

  test('redacts multiple URLs in one log line', () {
    final redacted = redactStreamText(
      'Primary http://alice:secret@one.example.com/live/alice/secret/1?token=abc and backup http://two.example.com/movie/bob/pass/2?username=bob',
    );

    expect(redacted, contains('one.example.com'));
    expect(redacted, contains('two.example.com'));
    expect(redacted, isNot(contains('alice:secret')));
    expect(redacted, isNot(contains('token=abc')));
    expect(redacted, isNot(contains('username=bob')));
  });

  test(
    'redacts mixed-case schemes, key variants, and prefixed Xtream paths',
    () {
      final redacted = redactStreamText(
        'Open HTTPS://iptv.example.com/base/api/LIVE/alice/secret/42'
        '?API_Key=sentinel-api&access-token=sentinel-token&quality=hd',
      );

      expect(redacted, contains('iptv.example.com'));
      expect(redacted, contains('42'));
      expect(redacted, contains('quality=hd'));
      expect(redacted, isNot(contains('alice')));
      expect(redacted, isNot(contains('secret')));
      expect(redacted, isNot(contains('sentinel-api')));
      expect(redacted, isNot(contains('sentinel-token')));
    },
  );

  test('fails closed for malformed URLs and removes local private paths', () {
    final malformed = redactStreamUrl('https://%zz/sentinel?token=secret');
    final text = redactStreamText(
      r'Failure at C:\Users\sentinel\Private Folder\epg.xml and '
      r'\\server\private\guide.xml with password=sentinel-pass',
    );

    expect(malformed, '[REDACTED_URL]');
    expect(text, isNot(contains('sentinel')));
    expect(text, isNot(contains('Private Folder')));
    expect(text, contains('[LOCAL_PATH]'));
    expect(text, contains('password=***'));
  });
}
