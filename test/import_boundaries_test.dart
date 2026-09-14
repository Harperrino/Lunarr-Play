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
      final sourceFeature = sourceLayer == 'features' && sourceParts.length > 1
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

  test('design-system and shimmer imports use the shared boundaries', () {
    final projectDirectory = Directory.current.absolute;
    final violations = <String>[];

    for (final rootName in const ['lib', 'test']) {
      final root = Directory('${projectDirectory.path}/$rootName');
      for (final entity in root.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;

        final source = _relativeProjectPath(projectDirectory, entity);
        final contents = entity.readAsStringSync();
        for (final match in _directivePattern.allMatches(contents)) {
          final uri = match.group(1)!;
          if (uri == 'package:flutter/material.dart') {
            violations.add('$source imports legacy Flutter Material');
          }
          if (uri == 'package:shimmer/shimmer.dart' &&
              source != 'lib/shared/widgets/app_shimmer.dart') {
            violations.add('$source bypasses AppShimmer');
          }
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'Design-system boundary violations:\n${violations.join('\n')}',
    );
  });

  test('both playback engines consume the shared player chrome boundary', () {
    const chromeImport =
        'package:m3uxtream_player/shared/widgets/player_chrome.dart';
    const tokenImport =
        'package:m3uxtream_player/shared/theme/player_chrome_tokens.dart';
    for (final path in const <String>[
      'lib/app/composition/player/widgets/player_transport_bar.dart',
      'lib/features/jellyfin/widgets/jellyfin_player_controls.dart',
    ]) {
      final imports = _projectImports(File(path));
      expect(imports, contains(chromeImport), reason: '$path bypasses chrome');
      expect(imports, contains(tokenImport), reason: '$path bypasses tokens');
    }
  });

  test('ambient rendering stays outside playback modules', () {
    const ambientImport =
        'package:m3uxtream_player/shared/widgets/app_ambient_background.dart';
    const ambientLayerImport =
        'package:m3uxtream_player/app/shell/app_ambient_layer.dart';
    const allowedConsumers = <String>{
      'lib/app/shell/app_ambient_layer.dart',
      'lib/features/settings/widgets/app_ambient_settings_section.dart',
    };
    final projectDirectory = Directory.current.absolute;
    final violations = <String>[];
    final layerConsumers = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = _relativeProjectPath(projectDirectory, entity);
      final imports = _projectImports(entity);
      if (imports.contains(ambientImport) &&
          !allowedConsumers.contains(source)) {
        violations.add(source);
      }
      if (imports.contains(ambientLayerImport)) layerConsumers.add(source);
    }

    expect(
      violations,
      isEmpty,
      reason:
          'Ambient renderer leaked outside app/settings boundaries: '
          '$violations',
    );
    expect(
      layerConsumers,
      const ['lib/app/shell/main_layout_screen.dart'],
      reason: 'The app ambient adapter must have one shell composition point.',
    );
    final shellSource = File('lib/app/shell/main_layout_screen.dart')
        .readAsStringSync();
    expect(
      RegExp(r'\bAppAmbientLayer\s*\(').allMatches(shellSource),
      hasLength(1),
      reason: 'The shell must mount exactly one app-wide ambient layer.',
    );
    expect(
      shellSource,
      contains('AppAmbientLayer(animationEnabled: !windowFullscreen)'),
      reason:
          'Every native player fullscreen path must suspend ambient motion, '
          'not only the Live-specific immersive layout.',
    );
  });

  test('discovery remains a leaf feature', () {
    final discovery = Directory('lib/features/discovery');
    final violations = <String>[];
    for (final entity in discovery.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      for (final uri in _projectImports(entity)) {
        const featurePrefix = 'package:m3uxtream_player/features/';
        if (uri.startsWith(featurePrefix) &&
            !uri.startsWith('${featurePrefix}discovery/')) {
          violations.add('${entity.path}: $uri');
        }
        if (uri.startsWith('package:m3uxtream_player/app/')) {
          violations.add('${entity.path}: $uri');
        }
      }
    }
    expect(
      violations,
      isEmpty,
      reason: 'Discovery leaf-boundary violations:\n${violations.join('\n')}',
    );
  });

  test('WebView dependencies are not part of the project', () {
    final projectDirectory = Directory.current.absolute;
    final violations = <String>[];

    for (final rootName in const ['lib', 'test']) {
      final root = Directory('${projectDirectory.path}/$rootName');
      for (final entity in root.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final source = _relativeProjectPath(projectDirectory, entity);
        final imports = _directivePattern
            .allMatches(entity.readAsStringSync())
            .map((match) => match.group(1)!);
        for (final import in imports) {
          if (import.toLowerCase().contains('webview')) {
            violations.add('$source: $import');
          }
        }
      }
    }

    final pubspec = File('pubspec.yaml').readAsStringSync().toLowerCase();
    if (pubspec.contains('webview')) violations.add('pubspec.yaml');
    for (final path in const [
      'pubspec.lock',
      'windows/flutter/generated_plugin_registrant.cc',
      'windows/flutter/generated_plugins.cmake',
    ]) {
      final file = File(path);
      if (file.existsSync() &&
          file.readAsStringSync().toLowerCase().contains('webview')) {
        violations.add(path);
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'WebView dependencies remain in the project: $violations',
    );
  });

  test('native media-kit fixtures are explicitly isolated', () {
    final projectDirectory = Directory.current.absolute;
    final violations = <String>[];

    for (final entity in Directory('test').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = _relativeProjectPath(projectDirectory, entity);
      if (source == 'test/helpers/media_kit_test_init.dart' ||
          source == 'test/import_boundaries_test.dart') {
        continue;
      }
      final contents = entity.readAsStringSync();
      if (!contents.contains('ensureMediaKitForTests()')) continue;
      final header = contents.split('\n').take(5).join('\n');
      if (!header.contains('@Tags') || !header.contains("'native'")) {
        violations.add(source);
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'Tests that initialize native media_kit state must carry the native '
          'tag and run in their own Flutter test process: $violations',
    );
  });
}

Set<String> _projectImports(File file) => _directivePattern
    .allMatches(file.readAsStringSync())
    .map((match) => match.group(1)!)
    .where((uri) => uri.startsWith('package:m3uxtream_player/'))
    .toSet();

String _relativeProjectPath(Directory projectDirectory, File file) {
  return file.absolute.path
      .substring(projectDirectory.path.length + 1)
      .replaceAll(r'\', '/');
}

String _relativeLibPath(Directory libDirectory, File file) {
  return file.absolute.path
      .substring(libDirectory.path.length + 1)
      .replaceAll(r'\', '/');
}

String? _resolveProjectTarget(Directory libDirectory, File source, String uri) {
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
      uri == 'package:flutter/rendering.dart' ||
      uri.startsWith('package:material_ui/');
}
