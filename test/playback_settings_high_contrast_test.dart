import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/app/providers/core_providers.dart';
import 'package:m3uxtream_player/features/player/providers/player_settings_providers.dart';
import 'package:m3uxtream_player/features/player/providers/vod_pre_buffer_settings_providers.dart';
import 'package:m3uxtream_player/features/settings/widgets/playback_settings_card.dart';
import 'package:m3uxtream_player/shared/theme/app_theme.dart';
import 'package:m3uxtream_player/shared/widgets/app_surface.dart';

class _TestPlayerBufferSecondsNotifier extends PlayerBufferSecondsNotifier {
  @override
  Future<int> build() async => PlayerBufferSecondsNotifier.defaultSeconds;
}

class _TestVodPreBufferNotifier extends VodPreBufferTargetSecondsNotifier {
  @override
  Future<int> build() async => VodPreBufferTargetSecondsNotifier.defaultSeconds;
}

class _TestForceStereoNotifier extends ForceStereoEnabledNotifier {
  @override
  Future<bool> build() async => false;
}

class _TestPreferredAudioLanguageNotifier
    extends PreferredAudioLanguageNotifier {
  @override
  Future<String?> build() async => null;
}

Widget _host({required bool highContrast}) {
  final theme = highContrast
      ? AppTheme.highContrastDarkTheme
      : AppTheme.darkTheme;
  return ProviderScope(
    overrides: [
      databaseProvider.overrideWith(
        (ref) => throw StateError('Playback contrast contract opened database'),
      ),
      playerBufferSecondsProvider.overrideWith(
        _TestPlayerBufferSecondsNotifier.new,
      ),
      vodPreBufferTargetSecondsProvider.overrideWith(
        _TestVodPreBufferNotifier.new,
      ),
      forceStereoEnabledProvider.overrideWith(_TestForceStereoNotifier.new),
      preferredAudioLanguageProvider.overrideWith(
        _TestPreferredAudioLanguageNotifier.new,
      ),
    ],
    child: MaterialApp(
      key: ValueKey<bool>(highContrast),
      theme: theme,
      home: const Scaffold(
        body: SizedBox(width: 760, height: 700, child: PlaybackSettingsCard()),
      ),
    ),
  );
}

Text _text(WidgetTester tester, String value) {
  return tester.widget<Text>(find.text(value));
}

Text _description(WidgetTester tester, String prefix) {
  return tester.widget<Text>(
    find.byWidgetPredicate(
      (widget) => widget is Text && widget.data?.startsWith(prefix) == true,
    ),
  );
}

void _expectRoles(WidgetTester tester, ColorScheme colors) {
  final surfaces = tester.widgetList<AppSurface>(find.byType(AppSurface));
  expect(
    surfaces.where((surface) => surface.level == AppSurfaceLevel.high),
    hasLength(1),
  );
  expect(
    surfaces.where((surface) => surface.level == AppSurfaceLevel.low),
    hasLength(2),
  );
  expect(
    _description(tester, 'Wie viel Puffer').style?.color,
    colors.onSurfaceVariant,
  );
  expect(
    _description(tester, 'VOD pre-buffer loads').style?.color,
    colors.onSurfaceVariant,
  );
  expect(_text(tester, 'Live-Startpuffer').style?.color, colors.onSurface);
  expect(_text(tester, 'VOD pre-buffer').style?.color, colors.onSurface);
  expect(_text(tester, 'Stereo erzwingen').style?.color, colors.onSurface);
  expect(
    _text(tester, 'Bevorzugte Audiosprache').style?.color,
    colors.onSurface,
  );

  final dropdowns = tester
      .widgetList<DropdownMenu<dynamic>>(
        find.byWidgetPredicate((widget) => widget is DropdownMenu),
      )
      .toList(growable: false);
  expect(dropdowns, hasLength(2));
  for (final dropdown in dropdowns) {
    expect(
      dropdown.inputDecorationTheme?.fillColor,
      colors.surfaceContainerHigh,
    );
    expect(dropdown.textStyle?.color, colors.onSurface);
  }

  final switchWidget = tester.widget<Switch>(find.byType(Switch));
  expect(switchWidget.activeThumbColor, isNull);
  expect(switchWidget.inactiveThumbColor, isNull);
  expect(switchWidget.inactiveTrackColor, isNull);
  final switchTheme = Theme.of(tester.element(find.byType(Switch))).switchTheme;
  expect(
    switchTheme.thumbColor?.resolve(const <WidgetState>{WidgetState.selected}),
    colors.onPrimary,
  );
  expect(
    switchTheme.thumbColor?.resolve(const <WidgetState>{}),
    colors.outline,
  );
  expect(
    switchTheme.trackColor?.resolve(const <WidgetState>{}),
    colors.surfaceContainerHighest,
  );
}

void main() {
  testWidgets(
    'playback settings neutral roles follow normal and high contrast',
    (tester) async {
      await tester.pumpWidget(_host(highContrast: false));
      await tester.pump();
      await tester.pump();
      final normalColors = AppTheme.darkTheme.colorScheme;
      _expectRoles(tester, normalColors);

      await tester.pumpWidget(_host(highContrast: true));
      await tester.pump();
      await tester.pump();
      final highContrastColors = AppTheme.highContrastDarkTheme.colorScheme;
      _expectRoles(tester, highContrastColors);
      expect(
        normalColors.onSurfaceVariant,
        isNot(highContrastColors.onSurfaceVariant),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
