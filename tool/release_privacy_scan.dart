import 'dart:convert';
import 'dart:io';

final class ReleasePrivacyFinding {
  const ReleasePrivacyFinding({
    required this.relativePath,
    required this.category,
  });

  final String relativePath;
  final String category;

  @override
  String toString() => '$relativePath: $category';
}

const _forbiddenFileSuffixes = <String>{
  '.db',
  '.db-shm',
  '.db-wal',
  '.env',
  '.jks',
  '.kdbx',
  '.key',
  '.keystore',
  '.m3u',
  '.m3u8',
  '.mobileconfig',
  '.mobileprovision',
  '.ovpn',
  '.p12',
  '.pem',
  '.pfx',
  '.sqlite',
  '.sqlite3',
};

const _forbiddenFileNames = <String>{
  '.netrc',
  '.npmrc',
  '.pypirc',
  'google-services.json',
  'googleservice-info.plist',
  'key.properties',
};

final _contentRules = <(String, RegExp)>[
  (
    'absolute Windows user-profile path',
    RegExp(
      r'''(?:file:///)?[a-z]:[\\/]+users[\\/]+[^\\/\x00-\x20]+[\\/]''',
      caseSensitive: false,
    ),
  ),
  (
    'absolute Unix user-profile path',
    RegExp(
      r'''file:///(?:home|users)/[^/\x00-\x20]+/''',
      caseSensitive: false,
    ),
  ),
  (
    'URL containing embedded credentials',
    RegExp(
      r'''(?:https?|rtsp|rtmp)://[^\s/:@]+:[^\s/@]+@''',
      caseSensitive: false,
    ),
  ),
  (
    'URL containing a private IPv4 address',
    RegExp(
      r'''(?:https?|wss?|rtsp|rtmp)://'''
      r'''(?:10(?:\.\d{1,3}){3}|192\.168(?:\.\d{1,3}){2}|'''
      r'''172\.(?:1[6-9]|2\d|3[01])(?:\.\d{1,3}){2})(?=[:/\s])''',
      caseSensitive: false,
    ),
  ),
  (
    'URL containing a private hostname',
    RegExp(
      r'''(?:https?|wss?|rtsp|rtmp)://[^\s/:]+\.'''
      r'''(?:home|internal|lan|local)(?=[:/\s])''',
      caseSensitive: false,
    ),
  ),
  (
    'private key material',
    RegExp(
      r'''-----BEGIN (?:[A-Z ]+ )?PRIVATE KEY-----'''
      r'''[\s\S]{80,8192}?'''
      r'''-----END (?:[A-Z ]+ )?PRIVATE KEY-----''',
    ),
  ),
  (
    'AWS access key',
    RegExp(r'''(?:AKIA|ASIA)[0-9A-Z]{16}'''),
  ),
  (
    'GitHub access token',
    RegExp(
      r'''(?:gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,})''',
    ),
  ),
  (
    'Google API key',
    RegExp(r'''AIza[0-9A-Za-z_-]{35}'''),
  ),
  (
    'OpenAI API key',
    RegExp(r'''sk-(?:proj-)?[A-Za-z0-9_-]{20,}'''),
  ),
  (
    'Slack token',
    RegExp(r'''xox[baprs]-[A-Za-z0-9-]{10,}'''),
  ),
];

Future<List<ReleasePrivacyFinding>> scanReleaseDirectory(
  Directory directory, {
  Map<String, String>? environment,
}) async {
  if (!await directory.exists()) {
    throw StateError('Release directory does not exist: ${directory.path}');
  }

  final findings = <ReleasePrivacyFinding>[];
  final root = directory.absolute.path;
  final privateMarkers = _readPrivateMarkers(
    environment ?? Platform.environment,
  );

  await for (final entity in directory.list(
    recursive: true,
    followLinks: false,
  )) {
    if (entity is! File) {
      continue;
    }

    final relativePath = _relativePath(root, entity.absolute.path);
    final lowerName = entity.uri.pathSegments.last.toLowerCase();
    if (_hasForbiddenFileName(lowerName)) {
      findings.add(
        ReleasePrivacyFinding(
          relativePath: relativePath,
          category: 'forbidden private-data file',
        ),
      );
    }

    final bytes = await entity.readAsBytes();
    final searchableRepresentations = <String>[
      latin1.decode(bytes),
      _projectUtf16LeAscii(bytes, 0),
      _projectUtf16LeAscii(bytes, 1),
    ];

    for (final (category, pattern) in _contentRules) {
      if (searchableRepresentations.any(pattern.hasMatch)) {
        findings.add(
          ReleasePrivacyFinding(
            relativePath: relativePath,
            category: category,
          ),
        );
      }
    }

    for (final marker in privateMarkers) {
      if (searchableRepresentations.any(
        (content) => content.toLowerCase().contains(marker),
      )) {
        findings.add(
          ReleasePrivacyFinding(
            relativePath: relativePath,
            category: 'configured private marker',
          ),
        );
      }
    }
  }

  findings.sort((left, right) {
    final pathResult = left.relativePath.compareTo(right.relativePath);
    return pathResult != 0 ? pathResult : left.category.compareTo(right.category);
  });
  return findings;
}

bool _hasForbiddenFileName(String lowerName) =>
    _forbiddenFileNames.contains(lowerName) ||
    lowerName.startsWith('.env.') ||
    (lowerName.startsWith('credentials') && lowerName.endsWith('.json')) ||
    (lowerName.startsWith('secrets') && lowerName.endsWith('.json')) ||
    _forbiddenFileSuffixes.any(lowerName.endsWith);

List<String> _readPrivateMarkers(Map<String, String> environment) =>
    (environment['LUNARR_RELEASE_PRIVATE_MARKERS'] ?? '')
        .split(',')
        .map((marker) => marker.trim().toLowerCase())
        .where((marker) => marker.length >= 4)
        .toSet()
        .toList(growable: false);

String _relativePath(String root, String path) {
  final normalizedRoot = root.replaceAll('\\', '/');
  final normalizedPath = path.replaceAll('\\', '/');
  if (normalizedPath == normalizedRoot) {
    return '.';
  }
  if (normalizedPath.startsWith('$normalizedRoot/')) {
    return normalizedPath.substring(normalizedRoot.length + 1);
  }
  return normalizedPath;
}

String _projectUtf16LeAscii(List<int> bytes, int offset) {
  final output = StringBuffer();
  for (var index = offset; index + 1 < bytes.length; index += 2) {
    final low = bytes[index];
    final high = bytes[index + 1];
    output.write(high == 0 && low >= 0x20 && low <= 0x7e
        ? String.fromCharCode(low)
        : '\u0000');
  }
  return output.toString();
}

Future<void> main(List<String> arguments) async {
  if (arguments.length != 1) {
    stderr.writeln('Usage: dart run tool/release_privacy_scan.dart <directory>');
    exitCode = 64;
    return;
  }

  final findings = await scanReleaseDirectory(Directory(arguments.single));
  if (findings.isEmpty) {
    stdout.writeln('Release privacy scan passed.');
    return;
  }

  stderr.writeln('Release privacy scan failed:');
  for (final finding in findings) {
    stderr.writeln('  - $finding');
  }
  stderr.writeln(
    'Build from a neutral path such as C:\\build\\Lunarr-Play and remove '
    'all private data before publishing.',
  );
  exitCode = 1;
}
