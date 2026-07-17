import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_fonts/src/google_fonts_base.dart' as google_fonts_test;
import 'package:m3uxtream_player/shared/theme/app_motion.dart';
import 'package:m3uxtream_player/shared/theme/app_shapes.dart';
import 'package:m3uxtream_player/shared/theme/app_spacing.dart';
import 'package:m3uxtream_player/shared/theme/app_status_colors.dart';
import 'package:m3uxtream_player/shared/theme/app_theme.dart';

double _contrastRatio(Color first, Color second) {
  final lighter = first.computeLuminance() >= second.computeLuminance()
      ? first
      : second;
  final darker = identical(lighter, first) ? second : first;
  return (lighter.computeLuminance() + 0.05) /
      (darker.computeLuminance() + 0.05);
}

class _InterTestAssetManifest implements AssetManifest {
  static const assets = <String>[
    'test_fonts/Inter-Regular.ttf',
    'test_fonts/Inter-ExtraBold.ttf',
  ];

  @override
  List<AssetMetadata>? getAssetVariants(String key) => null;

  @override
  List<String> listAssets() => assets;
}

String _flutterRoot() {
  final configuredRoot = Platform.environment['FLUTTER_ROOT'];
  if (configuredRoot != null && configuredRoot.isNotEmpty) {
    return configuredRoot;
  }

  var directory = File(Platform.resolvedExecutable).parent;
  for (var level = 0; level < 4; level++) {
    directory = directory.parent;
  }
  return directory.path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final fontDirectory = Directory(
      '${_flutterRoot()}${Platform.pathSeparator}bin${Platform.pathSeparator}'
      'cache${Platform.pathSeparator}artifacts${Platform.pathSeparator}'
      'material_fonts',
    );
    final regularBytes = await File(
      '${fontDirectory.path}${Platform.pathSeparator}roboto-regular.ttf',
    ).readAsBytes();
    final extraBoldBytes = await File(
      '${fontDirectory.path}${Platform.pathSeparator}roboto-bold.ttf',
    ).readAsBytes();

    google_fonts_test.assetManifest = _InterTestAssetManifest();
    GoogleFonts.config.allowRuntimeFetching = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
          if (message == null) return null;
          final key = utf8.decode(
            message.buffer.asUint8List(
              message.offsetInBytes,
              message.lengthInBytes,
            ),
          );
          final bytes = key.endsWith('Inter-ExtraBold.ttf')
              ? extraBoldBytes
              : key.endsWith('Inter-Regular.ttf')
              ? regularBytes
              : null;
          return bytes == null ? null : ByteData.sublistView(bytes);
        });
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
    google_fonts_test.assetManifest = null;
    google_fonts_test.clearCache();
    GoogleFonts.config.allowRuntimeFetching = true;
  });

  test('high-contrast dark theme strengthens semantic foreground roles', () {
    final normal = AppTheme.darkTheme;
    final highContrast = AppTheme.highContrastDarkTheme;
    final normalColors = normal.colorScheme;
    final colors = highContrast.colorScheme;
    final normalStatus = normal.extension<AppStatusColors>()!;
    final status = highContrast.extension<AppStatusColors>()!;

    expect(highContrast.useMaterial3, isTrue);
    expect(highContrast.brightness, Brightness.dark);
    expect(colors.brightness, Brightness.dark);
    expect(colors.onSurface, isNot(normalColors.onSurface));
    expect(colors.onSurfaceVariant, isNot(normalColors.onSurfaceVariant));
    expect(colors.outline, isNot(normalColors.outline));
    expect(colors.outlineVariant, isNot(normalColors.outlineVariant));
    expect(status.focus, isNot(normalStatus.focus));
    expect(status.live, isNot(normalStatus.live));
    expect(status.success, isNot(normalStatus.success));
    expect(status.warning, isNot(normalStatus.warning));
    expect(status.info, isNot(normalStatus.info));

    expect(highContrast.extension<AppSpacing>(), AppSpacing.standard);
    expect(highContrast.extension<AppShapes>(), AppShapes.standard);
    expect(highContrast.extension<AppMotion>(), AppMotion.standard);
    expect(highContrast.filledButtonTheme.style, isNotNull);
    expect(highContrast.outlinedButtonTheme.style, isNotNull);
  });

  test(
    'high-contrast text, control, outline, and focus pairs meet thresholds',
    () {
      final theme = AppTheme.highContrastDarkTheme;
      final colors = theme.colorScheme;
      final status = theme.extension<AppStatusColors>()!;
      final textPairs = <(Color, Color)>[
        (colors.onSurface, colors.surface),
        (colors.onSurfaceVariant, colors.surface),
        (colors.onPrimary, colors.primary),
        (colors.onPrimaryContainer, colors.primaryContainer),
        (colors.onSecondary, colors.secondary),
        (colors.onSecondaryContainer, colors.secondaryContainer),
        (colors.onTertiary, colors.tertiary),
        (colors.onTertiaryContainer, colors.tertiaryContainer),
        (colors.onError, colors.error),
        (colors.onErrorContainer, colors.errorContainer),
        (status.onLive, status.live),
        (status.onLiveContainer, status.liveContainer),
        (status.onSuccessContainer, status.successContainer),
        (status.onWarningContainer, status.warningContainer),
        (status.onInfoContainer, status.infoContainer),
      ];
      for (final (foreground, background) in textPairs) {
        expect(
          _contrastRatio(foreground, background),
          greaterThanOrEqualTo(4.5),
          reason: '$foreground on $background',
        );
      }

      for (final surface in <Color>[
        colors.surface,
        colors.surfaceContainer,
        colors.surfaceContainerHighest,
      ]) {
        expect(
          _contrastRatio(colors.outline, surface),
          greaterThanOrEqualTo(3),
          reason: 'outline on $surface',
        );
        expect(
          _contrastRatio(status.focus, surface),
          greaterThanOrEqualTo(3),
          reason: 'focus on $surface',
        );
      }
    },
  );

  testWidgets('MaterialApp selects its high-contrast dark theme', (
    tester,
  ) async {
    final normal = AppTheme.darkTheme;
    final highContrast = AppTheme.highContrastDarkTheme;

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          platformBrightness: Brightness.dark,
          highContrast: true,
        ),
        child: MaterialApp(
          themeMode: ThemeMode.dark,
          darkTheme: normal,
          highContrastDarkTheme: highContrast,
          home: Builder(
            builder: (context) {
              expect(
                Theme.of(context).colorScheme.onSurface,
                highContrast.colorScheme.onSurface,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
  });
}
