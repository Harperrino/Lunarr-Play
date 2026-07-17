import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_fonts/src/google_fonts_base.dart' as google_fonts_test;
import 'package:m3uxtream_player/shared/theme/app_color_roles.dart';
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

Future<ThemeData> _loadThemeWithLocalTestFonts() async {
  final theme = AppTheme.darkTheme;
  await GoogleFonts.pendingFonts();
  return theme;
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

  group('AppTheme dark contract', () {
    test('uses Material 3 with a dark color scheme', () async {
      final theme = await _loadThemeWithLocalTestFonts();
      expect(theme.useMaterial3, isTrue);
      expect(theme.brightness, Brightness.dark);
      expect(theme.colorScheme.brightness, Brightness.dark);
    });

    test(
      'maps the canonical application colors to their scheme roles',
      () async {
        final theme = await _loadThemeWithLocalTestFonts();
        final scheme = theme.colorScheme;
        expect(scheme.primary, const Color(0xFF78D7C7));
        expect(scheme.onPrimary, const Color(0xFF003731));
        expect(scheme.primaryContainer, const Color(0xFF155047));
        expect(scheme.onPrimaryContainer, const Color(0xFFA5F2E3));
        expect(scheme.secondary, const Color(0xFF91CDE0));
        expect(scheme.onSecondary, const Color(0xFF003641));
        expect(scheme.secondaryContainer, const Color(0xFF234E5A));
        expect(scheme.onSecondaryContainer, const Color(0xFFBCEBFA));
        expect(scheme.tertiary, const Color(0xFFE7C36E));
        expect(scheme.onTertiary, const Color(0xFF3C2F00));
        expect(scheme.tertiaryContainer, const Color(0xFF574600));
        expect(scheme.onTertiaryContainer, const Color(0xFFFFE39A));
        expect(scheme.error, const Color(0xFFFFB4AB));
        expect(scheme.onError, const Color(0xFF690005));
        expect(scheme.errorContainer, const Color(0xFF93000A));
        expect(scheme.onErrorContainer, const Color(0xFFFFDAD6));
        expect(scheme.surface, const Color(0xFF0B1417));
        expect(scheme.surfaceDim, const Color(0xFF071012));
        expect(scheme.surfaceBright, const Color(0xFF303A3D));
        expect(scheme.surfaceContainerLowest, const Color(0xFF081113));
        expect(scheme.surfaceContainerLow, const Color(0xFF0F191C));
        expect(scheme.surfaceContainer, const Color(0xFF152024));
        expect(scheme.surfaceContainerHigh, const Color(0xFF1B272B));
        expect(scheme.surfaceContainerHighest, const Color(0xFF223034));
        expect(scheme.onSurface, const Color(0xFFE2E9E7));
        expect(scheme.onSurfaceVariant, const Color(0xFFBBC9C6));
        expect(scheme.outline, const Color(0xFF85938F));
        expect(scheme.outlineVariant, const Color(0xFF3E4B48));
        expect(scheme.inverseSurface, const Color(0xFFDDE4E2));
        expect(scheme.onInverseSurface, const Color(0xFF2A3130));
        expect(scheme.inversePrimary, const Color(0xFF006B5E));
        expect(scheme.scrim, const Color(0xFF000000));
        expect(scheme.shadow, const Color(0xFF000000));
        expect(theme.scaffoldBackgroundColor, const Color(0xFF071012));
        expect(AppColorRoles.onBackground, const Color(0xFFE2E9E7));
        expect(AppTheme.primaryColor, scheme.primary);
        expect(AppTheme.secondaryColor, scheme.secondary);
        expect(AppTheme.accentColor, scheme.tertiary);
        expect(AppTheme.backgroundDb, AppColorRoles.background);
      },
    );

    test(
      'canonical text and control pairs meet their contrast targets',
      () async {
        final theme = await _loadThemeWithLocalTestFonts();
        final scheme = theme.colorScheme;
        final textPairs = <(Color, Color)>[
          (AppColorRoles.onBackground, AppColorRoles.background),
          (scheme.onSurface, scheme.surface),
          (scheme.onPrimary, scheme.primary),
          (scheme.onPrimaryContainer, scheme.primaryContainer),
          (scheme.onSecondary, scheme.secondary),
          (scheme.onSecondaryContainer, scheme.secondaryContainer),
          (scheme.onTertiary, scheme.tertiary),
          (scheme.onTertiaryContainer, scheme.tertiaryContainer),
          (scheme.onError, scheme.error),
          (scheme.onErrorContainer, scheme.errorContainer),
          (scheme.onInverseSurface, scheme.inverseSurface),
        ];
        for (final (foreground, background) in textPairs) {
          expect(
            _contrastRatio(foreground, background),
            greaterThanOrEqualTo(4.5),
            reason: '$foreground on $background',
          );
        }
      },
    );

    test('installs Material component themes', () async {
      final theme = await _loadThemeWithLocalTestFonts();
      expect(theme.filledButtonTheme.style, isNotNull);
      expect(theme.outlinedButtonTheme.style, isNotNull);
      expect(theme.inputDecorationTheme.filled, isTrue);
      expect(theme.tooltipTheme.decoration, isNotNull);
      expect(theme.chipTheme.shape, isA<StadiumBorder>());
      expect(theme.useMaterial3, isTrue);
      expect(theme.brightness, Brightness.dark);
    });

    test('installs every Material 3 token extension', () async {
      final theme = await _loadThemeWithLocalTestFonts();
      expect(theme.extension<AppStatusColors>(), AppStatusColors.dark);
      expect(theme.extension<AppSpacing>(), AppSpacing.standard);
      expect(theme.extension<AppShapes>(), AppShapes.standard);
      expect(theme.extension<AppMotion>(), AppMotion.standard);
    });
  });
}
