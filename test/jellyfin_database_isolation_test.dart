import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the jellyfin feature never touches Drift or the app database', () {
    final featureDirectory = Directory('lib/features/jellyfin').absolute;

    expect(featureDirectory.existsSync(), isTrue);

    final violations = <String>[];
    for (final entity in featureDirectory.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      for (final line in source.split('\n')) {
        final trimmed = line.trimLeft();
        if (!trimmed.startsWith('import ') && !trimmed.startsWith('export ')) {
          continue;
        }
        if (trimmed.contains('package:drift/') ||
            trimmed.contains('app_database') ||
            trimmed.contains('package:sqlite3')) {
          violations.add('${entity.absolute.path}:\n  $trimmed');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'Jellyfin credentials and metadata must never reach Drift:\n'
          '${violations.join('\n')}',
    );
  });
}
