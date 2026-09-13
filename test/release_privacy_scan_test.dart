import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/release_privacy_scan.dart';

void main() {
  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'lunarr-release-privacy-test-',
    );
  });

  tearDown(() async {
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('accepts a clean release directory', () async {
    await File('${temporaryDirectory.path}/app.txt').writeAsString(
      'https://example.invalid and fixture-token',
    );

    expect(await scanReleaseDirectory(temporaryDirectory), isEmpty);
  });

  test('detects an embedded Windows user-profile path', () async {
    await File('${temporaryDirectory.path}/app.so').writeAsString(
      'file:///C:/Users/private-user/project/generated.dart',
    );

    final findings = await scanReleaseDirectory(temporaryDirectory);

    expect(
      findings.map((finding) => finding.category),
      contains('absolute Windows user-profile path'),
    );
  });

  test('detects a UTF-16LE user-profile path', () async {
    const value = r'C:\Users\private-user\project\config.json';
    final bytes = <int>[];
    for (final codeUnit in value.codeUnits) {
      bytes
        ..add(codeUnit)
        ..add(0);
    }
    await File('${temporaryDirectory.path}/app.exe').writeAsBytes(bytes);

    final findings = await scanReleaseDirectory(temporaryDirectory);

    expect(
      findings.map((finding) => finding.category),
      contains('absolute Windows user-profile path'),
    );
  });

  test('detects private endpoints and configured markers', () async {
    await File('${temporaryDirectory.path}/app.so').writeAsString(
      'http://192.168.1.20:8096 and private-build-name',
    );

    final findings = await scanReleaseDirectory(
      temporaryDirectory,
      environment: const {
        'LUNARR_RELEASE_PRIVATE_MARKERS': 'private-build-name',
      },
    );

    expect(
      findings.map((finding) => finding.category),
      containsAll(<String>[
        'URL containing a private IPv4 address',
        'configured private marker',
      ]),
    );
  });

  test('detects files that can contain local credentials', () async {
    await Future.wait(<Future<File>>[
      File('${temporaryDirectory.path}/google-services.json')
          .writeAsString('{}'),
      File('${temporaryDirectory.path}/.env.production').writeAsString(''),
      File('${temporaryDirectory.path}/credentials-local.json')
          .writeAsString('{}'),
    ]);

    final findings = await scanReleaseDirectory(temporaryDirectory);

    expect(
      findings
          .where(
            (finding) => finding.category == 'forbidden private-data file',
          )
          .length,
      3,
    );
  });
}
