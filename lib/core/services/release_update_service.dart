import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:pub_semver/pub_semver.dart';

class AvailableRelease {
  const AvailableRelease(this.version, this.url);
  final String version;
  final Uri url;
}

/// One bounded public GitHub request per application lifetime, including failures.
class ReleaseUpdateService {
  ReleaseUpdateService({required this.currentVersion, required this.client});
  final Future<String> Function() currentVersion;
  final http.Client client;
  Future<AvailableRelease?>? _attempt;

  Future<AvailableRelease?> checkOnce() => _attempt ??= _check();

  Future<AvailableRelease?> _check() async {
    try {
      final installed = await currentVersion().timeout(
        const Duration(seconds: 8),
      );
      final response = await client
          .get(
            Uri.https(
              'api.github.com',
              '/repos/Harperrino/Lunarr-Play/releases/latest',
            ),
            headers: {
              'Accept': 'application/vnd.github+json',
              'User-Agent': 'Lunarr-Player',
            },
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      return newerFullRelease(installed, jsonDecode(response.body));
    } catch (_) {
      // Offline, rate limits, missing package metadata or malformed responses
      // must not block startup or cause a retry storm.
      return null;
    } finally {
      client.close();
    }
  }
}

AvailableRelease? newerFullRelease(String installed, Object? payload) {
  if (payload is! Map ||
      payload['draft'] != false ||
      payload['prerelease'] != false) {
    return null;
  }
  final tag = payload['tag_name'];
  if (tag is! String) return null;
  try {
    final latest = Version.parse(tag.startsWith('v') ? tag.substring(1) : tag);
    final local = Version.parse(installed);
    // Build numbers identify builds; they do not make the same full release newer.
    final localWithoutBuild = Version(
      local.major,
      local.minor,
      local.patch,
      pre: local.preRelease.isEmpty ? null : local.preRelease.join('.'),
    );
    final latestWithoutBuild = Version(
      latest.major,
      latest.minor,
      latest.patch,
    );
    if (latest.preRelease.isNotEmpty ||
        latestWithoutBuild <= localWithoutBuild) {
      return null;
    }
    // Construct the link ourselves instead of trusting a URL from the response.
    final url = Uri.https(
      'github.com',
      '/Harperrino/Lunarr-Play/releases/tag/$tag',
    );
    return AvailableRelease(latest.toString(), url);
  } on FormatException {
    return null;
  }
}
