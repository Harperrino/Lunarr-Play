import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/parsers/m3u_parser.dart';

void main() {
  group('M3uParser.extractEpgUrl', () {
    test('extracts url-tvg from double-quoted EXTM3U header', () {
      const content = '''
#EXTM3U url-tvg="https://epg.example.com/guide.xml.gz"
#EXTINF:-1 tvg-id="ch1",Channel One
http://stream.example.com/ch1.m3u8
''';

      expect(
        M3uParser.extractEpgUrl(content),
        'https://epg.example.com/guide.xml.gz',
      );
    });

    test('extracts url-tvg from single-quoted header', () {
      const content = "#EXTM3U url-tvg='http://localhost/epg.xml'\n";

      expect(M3uParser.extractEpgUrl(content), 'http://localhost/epg.xml');
    });

    test('returns null when header has no url-tvg', () {
      const content = '#EXTM3U\n#EXTINF:-1,Test\nhttp://x.com/a.m3u8\n';

      expect(M3uParser.extractEpgUrl(content), isNull);
    });

    test('returns null for empty content', () {
      expect(M3uParser.extractEpgUrl(''), isNull);
    });
  });
}
