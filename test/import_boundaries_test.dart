import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final RegExp _directivePattern = RegExp(
  r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''',
  multiLine: true,
);

void main() {
  test('production imports obey the modular dependency rule', () {
    final libDirectory = Directory('lib').absolute;
    final violations = <String>[];
    final featureEdges = <String>{};

    for (final entity in libDirectory.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;

      final source = _relativeLibPath(libDirectory, entity);
      final sourceParts = source.split('/');
      final sourceLayer = sourceParts.first;
      final sourceFeature =
          sourceLayer == 'features' && sourceParts.length > 1
          ? sourceParts[1]
          : null;
      final contents = entity.readAsStringSync();

      for (final match in _directivePattern.allMatches(contents)) {
        final uri = match.group(1)!;

        if (sourceLayer == 'core' && _isFlutterUiImport(uri)) {
          violations.add('$source imports Flutter UI: $uri');
          continue;
        }

        final target = _resolveProjectTarget(libDirectory, entity, uri);
        if (target == null) continue;
        final targetParts = target.split('/');
        final targetLayer = targetParts.first;

        if (sourceLayer == 'core' &&
            (targetLayer == 'app' || targetLayer == 'features')) {
          violations.add('$source -> $target');
        } else if (sourceLayer == 'shared' &&
            (targetLayer == 'app' || targetLayer == 'features')) {
          violations.add('$source -> $target');
        } else if (sourceLayer == 'features') {
          if (targetLayer == 'app') {
            violations.add('$source -> $target');
          } else if (targetLayer == 'features' &&
              targetParts.length > 1 &&
              targetParts[1] != sourceFeature) {
            final edge = '$sourceFeature->${targetParts[1]}';
            featureEdges.add(edge);
            violations.add('$source -> $target');
          }
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'Forbidden production import edges:\n${violations.join('\n')}\n'
          'Feature edges: ${featureEdges.toList()..sort()}',
    );
    expect(
      featureEdges,
      isEmpty,
      reason: 'Features must have zero cross-feature edges and cycles.',
    );
  });
}

String _relativeLibPath(Directory libDirectory, File file) {
  return file.absolute.path
      .substring(libDirectory.path.length + 1)
      .replaceAll(r'\', '/');
}

String? _resolveProjectTarget(
  Directory libDirectory,
  File source,
  String uri,
) {
  const packagePrefix = 'package:m3uxtream_player/';
  if (uri.startsWith(packagePrefix)) {
    return uri.substring(packagePrefix.length);
  }
  if (uri.startsWith('dart:') || uri.startsWith('package:')) return null;

  final resolved = source.parent.uri.resolve(uri).toFilePath();
  final normalized = File(resolved).absolute.path;
  final libPrefix = '${libDirectory.path}${Platform.pathSeparator}';
  if (!normalized.startsWith(libPrefix)) return null;
  return normalized.substring(libPrefix.length).replaceAll(r'\', '/');
}

bool _isFlutterUiImport(String uri) {
  return uri == 'dart:ui' ||
      uri == 'package:flutter/material.dart' ||
      uri == 'package:flutter/cupertino.dart' ||
      uri == 'package:flutter/widgets.dart' ||
      uri == 'package:flutter/rendering.dart';
}
